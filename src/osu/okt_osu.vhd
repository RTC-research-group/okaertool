-- Output Sequencer Unit (OSU)
--
-- Drives the AER output port. Depending on the command (cmd) it works as:
--   * Monitor:   the output is inactive; the IMU ack is connected to the ECU ack.
--   * Bypass:    the events from the IMU are forwarded to the output.
--   * Merge:     monitor + bypass; a latch waits for both acks before acknowledging the IMU.
--   * Sequencer: the events received from the PC through USB are stored in a FIFO and sent to the output when their
--                timestamp expires. Each event is a pair of words (timestamp, address); the timestamp is the time
--                to wait since the previous event. A timestamp of 0xFFFFFFFF is an overflow marker that makes the
--                sequencer wait for a full wrap of the timestamp counter.

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;        -- @suppress "Deprecated package"
use ieee.numeric_std.all;
use work.okt_global_pkg.all;
use work.okt_fifo_pkg.all;
use work.okt_top_pkg.all;
use work.okt_cu_pkg.all;

entity okt_osu is
	Port(
		-- System ports
		clk                : in  std_logic;
		rst_n              : in  std_logic;
		-- Monitor / bypass data in
		aer_in_data        : in  std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		req_in_data_n      : in  std_logic;
		ecu_in_ack_n       : in  std_logic;
		-- Command
		cmd                : in  std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
		-- CU interface - sequencer data in (USB)
		in_data            : in  std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		in_wr              : in  std_logic;
		in_ready           : out std_logic;
		-- AER data out
		node_in_data       : out std_logic_vector(OUT_DATA_BITS_WIDTH - 1 downto 0);
		node_req_n         : out std_logic;
		node_in_osu_ack_n  : in  std_logic;
		-- Multiplexed ack
		ecu_node_out_ack_n : out std_logic
	);
end okt_osu;

architecture Behavioral of okt_osu is

	-- FIFO signals
	signal fifo_w_data     : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_w_en       : std_logic;
	signal fifo_r_data     : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_r_en       : std_logic;
	signal fifo_empty      : std_logic;
	signal fifo_fill_count : integer range FIFO_DEPTH - 1 downto 0;

	signal usb_ready         : std_logic;
	signal fifo_w_en_end     : std_logic;
	signal fifo_w_en_latched : std_logic;

	-- System signals
	signal n_command      : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	signal ecu_node_ack_n : std_logic;  -- Ack latched until both the ECU and the output have acknowledged

	signal out_req            : std_logic := '1'; -- Output request
	signal out_ack            : std_logic := '1'; -- Output ack
	signal aer_data, limit_ts : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);

	signal rise_timestamp, next_timestamp : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);

	-- Pipelined timestamp comparison, stage 1: registered FIFO data and pre-decoded special values
	signal limit_ts_reg     : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	signal limit_ts_is_ovf  : std_logic; -- limit_ts = 0xFFFFFFFF
	signal limit_ts_is_zero : std_logic; -- limit_ts = 0

	-- Pipelined timestamp comparison, stage 2: registered arithmetic and comparisons
	signal limit_ts_minus_2   : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	signal timestamp_plus_2   : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	signal comp_ts_gt_limit   : std_logic;
	signal comp_ts_near_limit : std_logic;
	signal ovf_limit_minus_2  : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	signal comp_ts_gt_ovf     : std_logic;

	type state is (idle, timestamp_check, wait_ack_rise, data_trigger_0, data_trigger_1, data_trigger_2, wait_ovf);
	signal r_okt_osu_control_state, n_okt_osu_control_state : state;

begin

	n_command <= cmd;

	ring_buffer : entity work.ring_buffer
		generic map(
			RAM_DEPTH => FIFO_DEPTH,
			RAM_WIDTH => 32
		)
		port map(
			clk        => clk,
			rst        => rst_n,
			wr_data    => fifo_w_data,
			wr_en      => fifo_w_en,
			rd_data    => fifo_r_data,
			rd_en      => fifo_r_en,
			empty      => fifo_empty,
			fill_count => fifo_fill_count
		);

	fifo_w_data <= in_data;
	fifo_w_en   <= in_wr;
	in_ready    <= usb_ready;

	--------------------------------------------------------------------------------------------------------------------
	-- Output multiplexer
	--------------------------------------------------------------------------------------------------------------------
	Output_MUX : process(rst_n, n_command, ecu_in_ack_n, node_in_osu_ack_n, aer_data, out_req, ecu_node_ack_n, aer_in_data, req_in_data_n)
	begin
		-- Default values (also applied while in reset): outputs inactive
		node_req_n         <= '1';
		ecu_node_out_ack_n <= '1';
		node_in_data       <= (others => '0');
		out_ack            <= '1';

		if rst_n /= '0' then
			case n_command(2 downto 0) is

				when Mask_MON(2 downto 0) =>    -- Monitor: output inactive, the IMU ack comes from the ECU
					ecu_node_out_ack_n <= ecu_in_ack_n;

				when Mask_PASS(2 downto 0) =>   -- Bypass: the IMU ack comes from the output
					ecu_node_out_ack_n <= node_in_osu_ack_n;
					node_in_data       <= aer_in_data(OUT_DATA_BITS_WIDTH - 1 downto 0);
					node_req_n         <= req_in_data_n;

				when (Mask_MON(2 downto 0) or Mask_PASS(2 downto 0)) => -- Merge: the IMU ack waits for the ECU and the output
					ecu_node_out_ack_n <= ecu_node_ack_n;
					node_in_data       <= aer_in_data(OUT_DATA_BITS_WIDTH - 1 downto 0);
					node_req_n         <= req_in_data_n;

				when Mask_SEQ(2 downto 0) =>    -- Sequencer: the output is driven by the FSM, internal acks are cut
					node_in_data <= aer_data(OUT_DATA_BITS_WIDTH - 1 downto 0);
					node_req_n   <= out_req;
					out_ack      <= node_in_osu_ack_n;

				when (Mask_MON(2 downto 0) or Mask_SEQ(2 downto 0)) => -- Debug: sequencer output + ECU ack
					node_in_data       <= aer_data(OUT_DATA_BITS_WIDTH - 1 downto 0);
					node_req_n         <= out_req;
					out_ack            <= node_in_osu_ack_n;
					ecu_node_out_ack_n <= ecu_in_ack_n;

				when others =>                  -- Rest of commands: output inactive
					null;

			end case;
		end if;
	end process;

	--------------------------------------------------------------------------------------------------------------------
	-- Ack latch for the merge command: a new event is acknowledged only after both acks have been received
	-- (no timeout for the moment)
	--------------------------------------------------------------------------------------------------------------------
	ACK_latch : process(clk, rst_n)
	begin
		if rst_n = '0' then
			ecu_node_ack_n <= '1';
		elsif rising_edge(clk) then
			if ecu_in_ack_n = '0' and node_in_osu_ack_n = '0' then
				ecu_node_ack_n <= '0';
			elsif ecu_in_ack_n = '1' and node_in_osu_ack_n = '1' then
				ecu_node_ack_n <= '1';
			end if;
		end if;
	end process;

	--------------------------------------------------------------------------------------------------------------------
	-- FSM registers: control state and timestamp
	--------------------------------------------------------------------------------------------------------------------
	signals_update : process(clk, rst_n)
	begin
		if rst_n = '0' then
			r_okt_osu_control_state <= idle;
			rise_timestamp          <= (others => '0');

		elsif rising_edge(clk) then
			r_okt_osu_control_state <= n_okt_osu_control_state;
			rise_timestamp          <= next_timestamp;
		end if;
	end process signals_update;

	--------------------------------------------------------------------------------------------------------------------
	-- Pipelined timestamp comparison (2 stages to break the critical path)
	--------------------------------------------------------------------------------------------------------------------
	timestamp_pipeline : process(clk, rst_n)
	begin
		if rst_n = '0' then
			limit_ts_reg       <= (others => '0');
			limit_ts_is_ovf    <= '0';
			limit_ts_is_zero   <= '1';
			limit_ts_minus_2   <= (others => '0');
			timestamp_plus_2   <= (others => '0');
			comp_ts_gt_limit   <= '0';
			comp_ts_near_limit <= '0';
			ovf_limit_minus_2  <= (others => '0');
			comp_ts_gt_ovf     <= '0';
		elsif rising_edge(clk) then
			-- Stage 1: register the FIFO data only, to break the critical path from the BRAM
			limit_ts_reg <= fifo_r_data(TIMESTAMP_BITS_WIDTH - 1 downto 0);

			-- Stage 2: pre-decode special values and do the arithmetic on the registered data
			if limit_ts_reg = x"FFFFFFFF" then
				limit_ts_is_ovf <= '1';
			else
				limit_ts_is_ovf <= '0';
			end if;

			if limit_ts_reg = x"00000000" then
				limit_ts_is_zero <= '1';
			else
				limit_ts_is_zero <= '0';
			end if;

			limit_ts_minus_2  <= limit_ts_reg - 2;
			timestamp_plus_2  <= rise_timestamp + 2;
			ovf_limit_minus_2 <= TIMESTAMP_OVF - 2;

			-- Comparisons used by the timestamp_check state
			if rise_timestamp > limit_ts_minus_2 then
				comp_ts_gt_limit <= '1';
			else
				comp_ts_gt_limit <= '0';
			end if;

			if timestamp_plus_2 > limit_ts_reg then
				comp_ts_near_limit <= '1';
			else
				comp_ts_near_limit <= '0';
			end if;

			-- Comparison used by the wait_ovf state
			if rise_timestamp > ovf_limit_minus_2 then
				comp_ts_gt_ovf <= '1';
			else
				comp_ts_gt_ovf <= '0';
			end if;
		end if;
	end process timestamp_pipeline;

	--------------------------------------------------------------------------------------------------------------------
	-- Sequencer FSM: takes the events from the FIFO and sends them to the output when their timestamp expires.
	-- It only uses registered flags (limit_ts_is_ovf, limit_ts_is_zero, comp_*) to avoid long combinational paths.
	--------------------------------------------------------------------------------------------------------------------
	output_sequencer : process(r_okt_osu_control_state, out_ack, n_command, fifo_empty, rise_timestamp, fifo_r_data, limit_ts_is_ovf, limit_ts_is_zero, comp_ts_gt_limit, comp_ts_near_limit, comp_ts_gt_ovf)
	begin
		n_okt_osu_control_state <= r_okt_osu_control_state;
		next_timestamp          <= rise_timestamp + 1;

		fifo_r_en <= '0';
		aer_data  <= (others => '0');
		limit_ts  <= (others => '0');
		out_req   <= '1';

		case r_okt_osu_control_state is

			when idle =>
				if (out_ack = '1' and n_command(2) = '1' and fifo_empty = '0') then
					n_okt_osu_control_state <= timestamp_check;
				end if;

			when timestamp_check =>
				limit_ts <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);

				if (limit_ts_is_ovf = '1') then
					fifo_r_en               <= '1';
					n_okt_osu_control_state <= wait_ovf;
				-- limit_ts_is_zero = '0' means limit_ts > 0
				elsif (limit_ts_is_zero = '0' and (comp_ts_gt_limit = '1' or comp_ts_near_limit = '1')) then
					fifo_r_en               <= '1';
					n_okt_osu_control_state <= data_trigger_0;
					next_timestamp          <= (others => '0');
				end if;

			when data_trigger_0 =>
				n_okt_osu_control_state <= data_trigger_1;

			when data_trigger_1 =>
				aer_data <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);
				out_req  <= '0';
				if (out_ack = '0') then
					n_okt_osu_control_state <= data_trigger_2;
				end if;

			when data_trigger_2 =>
				aer_data                <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);
				n_okt_osu_control_state <= wait_ack_rise;
				fifo_r_en               <= '1';

			when wait_ack_rise =>
				if (out_ack = '1') then
					aer_data                <= (others => '0');
					n_okt_osu_control_state <= idle;
				end if;

			when wait_ovf =>
				-- Wait for a full wrap of the timestamp counter
				limit_ts(TIMESTAMP_BITS_WIDTH - 1 downto 0) <= TIMESTAMP_OVF;

				if (comp_ts_gt_ovf = '1') then
					aer_data                <= (others => '0');
					fifo_r_en               <= '1';
					n_okt_osu_control_state <= idle;
				end if;
		end case;
	end process output_sequencer;

	--------------------------------------------------------------------------------------------------------------------
	-- USB ready: the PC can send data while the FIFO has room. Each burst is limited to USB_BURST_WORDS words.
	-- TODO: avoid blocking when the FIFO fills up
	--------------------------------------------------------------------------------------------------------------------
	control_usb_ready : process(clk, rst_n) is
		variable usb_burst : integer range 0 to FIFO_DEPTH - 1;
	begin
		if rst_n = '0' then
			usb_ready         <= '0';
			usb_burst         := 0;
			fifo_w_en_end     <= '0';
			fifo_w_en_latched <= '0';

		elsif rising_edge(clk) then
			fifo_w_en_latched <= fifo_w_en;

			if fifo_w_en_latched = '1' and fifo_w_en = '0' then
				fifo_w_en_end <= '1';
			else
				fifo_w_en_end <= '0';
			end if;

			if fifo_fill_count < FIFO_DEPTH - FIFO_ALM_FULL_OFFSET then
				usb_ready <= '1';
				usb_burst := USB_BURST_WORDS;
			elsif usb_ready = '1' then
				usb_burst := usb_burst - 1;
				if usb_burst = 0 or fifo_w_en_end = '1' then
					usb_ready <= '0';
				end if;
			end if;

		end if;
	end process control_usb_ready;

end Behavioral;
