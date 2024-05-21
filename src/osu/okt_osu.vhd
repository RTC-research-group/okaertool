----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:02:24 03/20/2023 
-- Design Name: 
-- Module Name:    okt_osu - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;        -- @suppress "Deprecated package"
use ieee.numeric_std.all;
use work.okt_osu_pkg.all;
use work.okt_global_pkg.all;
use work.okt_fifo_pkg.all;
--use work.okt_top_pkg.all;

entity okt_osu is						-- Output Sequencer Unit
    Port(  
			  --System ports
		     clk   					: in  std_logic;
           rst_n 					: in  std_logic;
			  --MONITOR / PASS DATA IN
           aer_in_data  		: in  std_logic_vector (BUFFER_BITS_WIDTH - 1 downto 0);
           req_in_data_n 		: in  std_logic;
           ecu_in_ack_n 		: in  std_logic;
			  --Command
			  status    			: out std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
           cmd 					: in  std_logic_vector (COMMAND_BIT_WIDTH - 1 downto 0);
			  -- CU interface - SEQUENCER DATA IN (USB)
			  in_data  : in    std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
			  in_wr    : in    std_logic;
			  in_ready : out   std_logic;
			  -- AER DATA OUT
           node_in_data 		: out std_logic_vector(NODE_IN_DATA_BITS_WIDTH - 1 downto 0);
           node_req_n 			: out std_logic;
           node_in_osu_ack_n 	: in  std_logic;
			  --MULTIPLEXED ACK
			  ecu_node_out_ack_n : out std_logic
);
end okt_osu;

architecture Behavioral of okt_osu is

	-- FIFO signals
	signal fifo_w_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_w_en   		  : std_logic;
	signal fifo_r_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_r_en   		  : std_logic;
	signal fifo_empty  		  : std_logic;
	signal fifo_full   		  : std_logic;
	signal fifo_almost_full   : std_logic;
	signal fifo_almost_empty  : std_logic;
	signal fifo_fill_count 	  : integer range OSU_FIFO_DEPTH - 1 downto 0;
	--signal usb_burst : integer;
	
	signal usb_ready 			  : std_logic;
	signal fifo_w_en_end 	  : std_logic; 
   signal fifo_w_en_latched  : std_logic;
	
	--Sys signals
	signal n_command: std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	signal ecu_node_ack_n : std_logic := '1'; --Latched signal
	
	signal out_req: std_logic := '1'; --output request
	signal out_ack: std_logic := '1'; --output ack
	signal aer_data, limit_ts: std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	
	
	signal rise_timestamp, next_timestamp : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	type state is (idle, timestamp_check, wait_ack_rise, data_trigger_0, data_trigger_1,data_trigger_2, wait_ovf);
	signal r_okt_osu_control_state, n_okt_osu_control_state : state;
	
	attribute enum_encoding : string;
	attribute enum_encoding of state : type is "IDLE 000, timestamp_check 001, wait_ack_rise 010, data_trigger_0 011, data_trigger_1 100, data_trigger_2 101, wait_ovf 110";


begin

	n_command <= cmd;
	status <= "00000" & usb_ready & fifo_empty & fifo_full;
	
--		sequencer_fifo : entity work.okt_fifo
--		generic map(
--			DEPTH => OSU_FIFO_DEPTH
--		)
--		port map(
--			clk    => clk,
--			rst_n  => rst_n,
--			w_data => fifo_w_data,
--			w_en   => fifo_w_en,
--			r_data => fifo_r_data,
--			r_en   => fifo_r_en,
--			empty  => fifo_empty,
--			full   => fifo_full,
--			almost_full => fifo_almost_full,
--			almost_empty => fifo_almost_empty
--		);
		
		ring_buffer : entity work.ring_buffer
		generic map(
			RAM_DEPTH => OSU_FIFO_DEPTH,
			RAM_WIDTH => 32
		)
		port map(
			clk    => clk,
			rst  => rst_n,
			wr_data => fifo_w_data,
			wr_en   => fifo_w_en,
			rd_data => fifo_r_data,
			rd_en   => fifo_r_en,
			empty  => fifo_empty,
			full   => fifo_full,
			full_next => fifo_almost_full,
			fill_count => fifo_fill_count,
			empty_next => fifo_almost_empty
		);
		
			fifo_w_data  <= in_data;
		   fifo_w_en <= in_wr;
		   in_ready <= usb_ready;
			
	
--------------------------------------------------------------------------------------------------------------------
--Output Multiplexer
--------------------------------------------------------------------------------------------------------------------
	Output_MUX: process (rst_n, n_command, ecu_in_ack_n, node_in_osu_ack_n, aer_data, out_req, ecu_node_ack_n, aer_in_data, req_in_data_n)
	begin
	  if rst_n = '0' then --Reset all values to inactive when RST is active (low)
		 node_req_n <= '1';
		 ecu_node_out_ack_n <= '1';
		 node_in_data <= (others => '0');
		 out_ack <= '1';
	  else
		node_req_n <= '1';
		ecu_node_out_ack_n <= '1';
		node_in_data <= (others => '0');
		out_ack <= '1';
		  
		 case n_command is
		 
			when "001" => --MONITOR: Deactivates output and has IMU_ack connected to ECU_ack
				ecu_node_out_ack_n <= ecu_in_ack_n;

			when "010" => --PASS: bypasses output and connects IMU_ack to OUT_ack
				ecu_node_out_ack_n <= node_in_osu_ack_n;
				node_in_data <= aer_in_data;
				node_req_n <= req_in_data_n;

			when "011" => --MERGER: bypasses output and connects OUT_ACK and EMU_ACK to IMU_ACK via latch
				ecu_node_out_ack_n <= ecu_node_ack_n;
				node_in_data <= aer_in_data;
				node_req_n <= req_in_data_n;

			when "100" => --SEQUENCER: Activates output and cuts connections to internal ack signals
				node_in_data <= aer_data;
				node_req_n <= out_req;
				out_ack <= node_in_osu_ack_n;
				
			when "101" => --DEBUG: TODO
				node_in_data <= aer_data;
				node_req_n <= out_req;
				out_ack <= node_in_osu_ack_n;
				ecu_node_out_ack_n <= ecu_in_ack_n;

			when others => --TODO
			
		 end case;
	  end if;
	end process;

--------------------------------------------------------------------------------------------------------------------
--ACK Latch for bypass and monitor commands
--------------------------------------------------------------------------------------------------------------------
	-- ACK_Latch: Latches ACK signals so that a new message is sent only after having received both acks. No timeout for the moment.
	ACK_latch: process (ecu_in_ack_n, node_in_osu_ack_n)
	begin
		if ecu_in_ack_n = '0' and node_in_osu_ack_n = '0' then
			ecu_node_ack_n <= '0';
		elsif ecu_in_ack_n = '1' and node_in_osu_ack_n = '1' then
			ecu_node_ack_n <= '1';
		end if;
	end process;

--------------------------------------------------------------------------------------------------------------------
--FSM synchronous signals
--------------------------------------------------------------------------------------------------------------------
	-- signals_update: This process will update the control_state and timestamp signals
	signals_update : process(clk, rst_n)
	begin
		if rst_n = '0' then
			r_okt_osu_control_state <= idle;
			rise_timestamp             <= (others => '0');
		
		elsif rising_edge(clk) then
			r_okt_osu_control_state <= n_okt_osu_control_state;
			rise_timestamp             <= next_timestamp;
		end if;
	end process signals_update;
	
	
--------------------------------------------------------------------------------------------------------------------
--FSM sequencer code. Beta VER.
--------------------------------------------------------------------------------------------------------------------
	-- Take data from FIFO - REVISAR
	output_sequencer: process(r_okt_osu_control_state, out_ack, n_command, fifo_empty, rise_timestamp)
	begin
		n_okt_osu_control_state <= r_okt_osu_control_state;
		next_timestamp             <= rise_timestamp + 1;	

		fifo_r_en               	<= '0';
		aer_data							<= (others => '0');
		limit_ts							<= (others => '0');
		out_req							<= '1';

		case r_okt_osu_control_state is
		
			when idle =>
				if (out_ack = '1' and n_command(2) = '1' and fifo_empty = '0') then
					n_okt_osu_control_state 			<= timestamp_check;
				end if;

			when timestamp_check =>
				limit_ts <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);
				if (limit_ts = x"FFFFFFFF") then
					fifo_r_en                        <= '1';
					n_okt_osu_control_state 			<= wait_ovf;
				elsif (limit_ts > 0 and (rise_timestamp > limit_ts - 2 or rise_timestamp +2 > limit_ts)) then
					fifo_r_en                        <= '1';
					n_okt_osu_control_state          <= data_trigger_0;
					next_timestamp                      <= (others => '0');
				end if;

			when data_trigger_0 =>
				n_okt_osu_control_state <= data_trigger_1;

			when data_trigger_1 =>
				aer_data <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);
				out_req <= '0';
				if (out_ack = '0') then
					n_okt_osu_control_state <= data_trigger_2;
				end if;
				
			when data_trigger_2 =>
				aer_data <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0);
				n_okt_osu_control_state <= wait_ack_rise;
				fifo_r_en <= '1';				
				
			when wait_ack_rise =>
				if (out_ack = '1') then
					aer_data <= (others => '0');
					n_okt_osu_control_state <= idle;
				end if;

			when wait_ovf =>
			limit_ts (TIMESTAMP_BITS_WIDTH - 1 downto 0) <= TIMESTAMP_OVF;
				if (limit_ts > 0 and rise_timestamp > limit_ts - 2) then
					aer_data <= (others => '0');
					fifo_r_en <= '1';
					n_okt_osu_control_state <= idle;
				end if;
		end case;
	end process output_sequencer;
		
	
----------------------------------------------------------------------------------------------------------------------
----Control USB.
----------------------------------------------------------------------------------------------------------------------
--	--Control USB: TODO: que no se bloquee al intentar llenarse de datos
--	control_usb_ready : process(clk, rst_n) is
--		variable usb_burst : integer;
--	begin
--		if rst_n = '0' then --RESET
--			usb_ready <= '0';
--			usb_burst := 0;
--			fifo_w_en_end <= '0';
--			fifo_w_en_latched <= '0';
--			
--		elsif rising_edge(clk) then --NORMAL
--			 fifo_w_en_latched <= fifo_w_en;									-- latched = enable	
--			if fifo_w_en_latched = '1' and fifo_w_en = '0' then		-- if latched = 1 and enable = 0
--				  fifo_w_en_end <= '1';											-- end = 1
--			else																		-- else
--				  fifo_w_en_end <= '0';											-- end = 0
--			end if;		
--			if fifo_almost_empty = '1' or fifo_empty = '1' then 		-- if fifo is getting empty
--				usb_ready <= '1';													-- ready = 1
--				usb_burst := USB_BURST_WORDS;									-- burst = 4096
--			elsif usb_ready = '1' then											-- else if ready = 1
--				 usb_burst := usb_burst - 1;									-- burst - 1
--				 if usb_burst = 0 or fifo_w_en_end = '1' then			-- if burst = 0 or end = 1
--					  usb_ready <= '0';											-- ready = 0
--				 end if;
--			end if;
--		end if;
--	end process control_usb_ready;
	
	
	
	
--------------------------------------------------------------------------------------------------------------------
--Control USB. version 2
--------------------------------------------------------------------------------------------------------------------
	--Control USB: TODO: que no se bloquee al intentar llenarse de datos
	control_usb_ready : process(clk, rst_n) is
	variable usb_burst : integer;
	begin
		if rst_n = '0' then --RESET
			usb_ready <= '0';
			usb_burst := 0;
			fifo_w_en_end <= '0';
			fifo_w_en_latched <= '0';
			
		elsif rising_edge(clk) then --NORMAL
			fifo_w_en_latched <= fifo_w_en;													
			
			if fifo_w_en_latched = '1' and fifo_w_en = '0' then		
			fifo_w_en_end <= '1';											
			else																	
				  fifo_w_en_end <= '0';											
			end if;		
			
			if fifo_fill_count < OSU_FIFO_DEPTH - FIFO_ALM_FULL_OFFSET then	
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



