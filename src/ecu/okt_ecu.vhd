-- Event Capture Unit (ECU)
--
-- Captures the AER events selected by the IMU, adds an absolute timestamp to each of them and stores the
-- (timestamp, address) word pairs in a FIFO. The CU module reads the FIFO and sends the data to the PC through USB.
--
-- Timestamp: a free-running counter that is held at 0 while the capture is disabled (cmd(0) = '0'). When it wraps
-- around, a special event with both words set to 0xFFFFFFFF is stored so the software can extend the timestamp.

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;        -- @suppress "Deprecated package"
use ieee.numeric_std.all;
use work.okt_fifo_pkg.all;
use work.okt_global_pkg.all;
use work.okt_top_pkg.all;

entity okt_ecu is
    Port(
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        -- IMU interface
        ecu_req_n     : in  std_logic;
        aer_data      : in  std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
        ecu_out_ack_n : out std_logic;
        -- CU interface
        out_data      : out std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
        out_rd        : in  std_logic;
        out_ready     : out std_logic; -- FIFO contains enough data for a USB transfer
        status        : out std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
        cmd           : in  std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0) -- cmd(0): enable capture
    );
end okt_ecu;

architecture Behavioral of okt_ecu is

    type   state                                            is (idle, req_fall_0, req_fall_1, wait_req_rise, timestamp_overflow_0, timestamp_overflow_1);
    signal r_okt_ecu_control_state, n_okt_ecu_control_state : state;

    signal r_timestamp, n_timestamp : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
    signal n_ack_n                  : std_logic;

    -- Latched so an overflow is never missed even if it happens while a normal event is being written
    signal r_timestamp_ovf_pending : std_logic;

    -- Registered increment of the timestamp, to break the critical path
    signal r_timestamp_plus_1 : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);

    signal ECU_fifo_w_data     : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
    signal ECU_fifo_w_en       : std_logic;
    signal ECU_fifo_r_data     : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
    signal ECU_fifo_r_en       : std_logic;
    signal ECU_fifo_empty      : std_logic;
    signal ECU_fifo_full       : std_logic;
    signal ECU_fifo_fill_count : integer range FIFO_DEPTH - 1 downto 0;

    signal ECU_usb_ready : std_logic;

    signal n_command : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);

    -- DEBUG
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of rst_n, ecu_req_n, aer_data, ecu_out_ack_n, out_data, out_rd, out_ready, cmd,
                            r_okt_ecu_control_state, n_okt_ecu_control_state, r_timestamp, n_timestamp,
                            n_ack_n, ECU_fifo_w_data, ECU_fifo_w_en, ECU_fifo_r_data, ECU_fifo_r_en,
                            ECU_fifo_full, ECU_fifo_fill_count, ECU_usb_ready, n_command,
                            r_timestamp_ovf_pending : signal is "TRUE";

begin

    ecu_out_ack_n <= n_ack_n;
    status        <= "00000" & ECU_usb_ready & ECU_fifo_empty & ECU_fifo_full;
    n_command     <= cmd;

    ring_buffer : entity work.ring_buffer
        generic map(
            RAM_DEPTH => FIFO_DEPTH,
            RAM_WIDTH => BUFFER_BITS_WIDTH
        )
        port map(
            clk        => clk,
            rst        => rst_n,
            wr_data    => ECU_fifo_w_data,
            wr_en      => ECU_fifo_w_en,
            rd_data    => ECU_fifo_r_data,
            rd_en      => ECU_fifo_r_en,
            empty      => ECU_fifo_empty,
            full       => ECU_fifo_full,
            fill_count => ECU_fifo_fill_count
        );

    out_data      <= ECU_fifo_r_data;
    ECU_fifo_r_en <= out_rd;
    out_ready     <= ECU_usb_ready;

    ----------------------------------------------------------------------------------------------------------------
    -- Registers: FSM state, timestamp, pending overflow flag and registered timestamp increment
    ----------------------------------------------------------------------------------------------------------------
    timestamp_pipeline : process(clk, rst_n)
    begin
        if rst_n = '0' then
            r_okt_ecu_control_state <= idle;
            r_timestamp             <= (others => '0');
            r_timestamp_ovf_pending <= '0';
            r_timestamp_plus_1      <= (others => '0');
        elsif rising_edge(clk) then
            r_okt_ecu_control_state <= n_okt_ecu_control_state;
            r_timestamp             <= n_timestamp;

            -- Latch the overflow condition so it survives until it can be safely handled, even if it occurs while
            -- req_fall_1/wait_req_rise are in the middle of writing a normal event
            if n_command(0) = '0' then
                r_timestamp_ovf_pending <= '0';
            elsif r_timestamp = TIMESTAMP_OVF then
                r_timestamp_ovf_pending <= '1';
            elsif r_okt_ecu_control_state = timestamp_overflow_0 then
                r_timestamp_ovf_pending <= '0';
            end if;

            r_timestamp_plus_1 <= n_timestamp + 1;
        end if;
    end process timestamp_pipeline;

    ----------------------------------------------------------------------------------------------------------------
    -- Input monitor: stores each event in the FIFO as two words, the timestamp followed by the AER data
    ----------------------------------------------------------------------------------------------------------------
    input_monitor : process(r_okt_ecu_control_state, ecu_req_n, r_timestamp, aer_data, ECU_fifo_full, n_command, r_timestamp_ovf_pending, r_timestamp_plus_1)
    begin
        n_okt_ecu_control_state <= r_okt_ecu_control_state;
        -- Absolute timestamp: held at 0 while capture is disabled, free-running otherwise
        if n_command(0) = '1' then
            n_timestamp <= r_timestamp_plus_1;
        else
            n_timestamp <= (others => '0');
        end if;
        n_ack_n         <= '1';
        ECU_fifo_w_data <= (others => '0');
        ECU_fifo_w_en   <= '0';

        case r_okt_ecu_control_state is
            when idle =>
                if (n_command(0) = '0') then
                    n_okt_ecu_control_state <= idle;

                elsif (ecu_req_n = '0' and n_command(0) = '1') then
                    n_okt_ecu_control_state <= req_fall_0;

                elsif (r_timestamp_ovf_pending = '1' and n_command(0) = '1') then
                    n_okt_ecu_control_state <= timestamp_overflow_0;
                end if;

            when req_fall_0 =>
                if (r_timestamp_ovf_pending = '1') then
                    n_okt_ecu_control_state <= timestamp_overflow_0;

                elsif (ECU_fifo_full = '0') then
                    -- The timestamp keeps running after an event is captured
                    ECU_fifo_w_data(TIMESTAMP_BITS_WIDTH - 1 downto 0) <= r_timestamp;
                    ECU_fifo_w_en                                      <= '1';
                    n_okt_ecu_control_state                            <= req_fall_1;
                end if;

            when req_fall_1 =>
                if (ECU_fifo_full = '0') then
                    ECU_fifo_w_data(BUFFER_BITS_WIDTH - 1 downto 0) <= aer_data;
                    ECU_fifo_w_en                                   <= '1';
                    n_okt_ecu_control_state                         <= wait_req_rise;
                end if;

            when wait_req_rise =>
                n_ack_n <= '0';
                if (ecu_req_n = '1') then
                    n_okt_ecu_control_state <= idle;
                end if;

            -- Timestamp overflow event: both the timestamp word and the data word are 0xFFFFFFFF
            when timestamp_overflow_0 =>
                if (ECU_fifo_full = '0') then
                    ECU_fifo_w_data         <= (others => '1');
                    ECU_fifo_w_en           <= '1';
                    n_timestamp             <= (others => '0');
                    n_okt_ecu_control_state <= timestamp_overflow_1;
                end if;

            when timestamp_overflow_1 =>
                if (ECU_fifo_full = '0') then
                    ECU_fifo_w_data         <= (others => '1');
                    ECU_fifo_w_en           <= '1';
                    n_timestamp             <= (others => '0');
                    n_okt_ecu_control_state <= idle;
                end if;
        end case;
    end process;

    ----------------------------------------------------------------------------------------------------------------
    -- USB ready: the FIFO is read out through a block-throttled pipe, so it only requests a transfer when it holds
    -- more than FIFO_ALM_EMPTY_OFFSET words
    ----------------------------------------------------------------------------------------------------------------
    control_ECU_usb_ready : process(clk, rst_n) is
    begin
        if rst_n = '0' then
            ECU_usb_ready <= '0';
        elsif rising_edge(clk) then
            if ECU_fifo_fill_count > FIFO_ALM_EMPTY_OFFSET then
                ECU_usb_ready <= '1';
            else
                ECU_usb_ready <= '0';
            end if;
        end if;
    end process;

end Behavioral;
