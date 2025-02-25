
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;        -- @suppress "Deprecated package"
use ieee.numeric_std.all;
use work.okt_ecu_pkg.all;
use work.okt_fifo_pkg.all;
use work.okt_global_pkg.all;

entity okt_ecu is                       -- Event Capture Unit
	Port(
		clk       : in  std_logic;
		rst_n     : in  std_logic;
		ecu_req_n : in  std_logic;
		aer_data  : in  std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		ecu_out_ack_n     : out std_logic;
		
		-- CU interface
		out_data  : out std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		out_rd    : in  std_logic;
		out_ready : out std_logic;
		--
		
		status    : out std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
		cmd		 : in std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0)
);
end okt_ecu;

architecture Behavioral of okt_ecu is

	type state is (idle, req_fall_0, req_fall_1, wait_req_rise, timestamp_overflow_0, timestamp_overflow_1);
	signal r_okt_ecu_control_state, n_okt_ecu_control_state : state;

	signal r_timestamp, n_timestamp : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	signal ecu_req_s                : std_logic;
	signal n_ack_n                  : std_logic;

--INPUT SIGNALS
	signal IMU_data : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0');
	signal data_error : std_logic := '0';
	signal polarity : std_logic;
	signal vertical : std_logic_vector(8 downto 0):= (others => '0');
	signal horizontal : std_logic_vector(8 downto 0):= (others => '0');


--FIFO SIGNALS
	signal ECU_fifo_w_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal ECU_fifo_w_en   		  : std_logic;
	signal ECU_fifo_r_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal ECU_fifo_r_en   		  : std_logic;
	signal ECU_fifo_empty  		  : std_logic;
	signal ECU_fifo_full  		  : std_logic;
	signal ECU_fifo_almost_full   : std_logic;
	signal ECU_fifo_almost_empty   : std_logic;
	signal ECU_fifo_fill_count 	: integer range FIFO_DEPTH - 1 downto 0;
	--signal usb_burst : integer;

--USB SIGNALS
	signal ECU_usb_ready 		  : std_logic;
	signal ECU_fifo_r_en_end 	  : std_logic; 
    signal ECU_fifo_r_en_latched  : std_logic;
	
--CONTROL SIGNALS
	signal ECU_n_command: std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);

-- DEBUG
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of r_okt_ecu_control_state, n_okt_ecu_control_state, r_timestamp, n_timestamp, n_ack_n : signal is "TRUE";

begin

	ecu_req_s <= ecu_req_n;
	ecu_out_ack_n <= n_ack_n;
	status <= "00000" & ECU_usb_ready & ECU_fifo_empty & ECU_fifo_full;
	ECU_n_command <= cmd;
	--IMU_data <= aer_data;
	
	--merger
	polarity <= aer_data (0);
    horizontal(7 downto 0) <= aer_data (8 downto 1);
    vertical(7 downto 0) <= aer_data (16 downto 9);

	
-------------------------------------------------------------
-- FIFO
-------------------------------------------------------------	
	ring_buffer : entity work.ring_buffer
		generic map(
			RAM_DEPTH => FIFO_DEPTH,
			RAM_WIDTH => 32
		)
		port map(
			clk    => clk,
			rst  => rst_n,
			wr_data => ECU_fifo_w_data,
			wr_en   => ECU_fifo_w_en,
			rd_data => ECU_fifo_r_data,
			rd_en   => ECU_fifo_r_en,
			empty  => ECU_fifo_empty,
			full   => ECU_fifo_full,
			full_next => ECU_fifo_almost_full,
			fill_count => ECU_fifo_fill_count,
			empty_next => ECU_fifo_almost_empty
		);

	out_data  <= ECU_fifo_r_data;
	ECU_fifo_r_en <= out_rd;
	out_ready <= ECU_usb_ready;

-------------------------------------------------------------
-- UPDATE FSM AND TIMESTAMP
-------------------------------------------------------------
	signals_update : process(clk, rst_n)
	begin
		if rst_n = '0' then
			r_okt_ecu_control_state <= idle;
			r_timestamp             <= (others => '0');
		
		elsif rising_edge(clk) then
			r_okt_ecu_control_state <= n_okt_ecu_control_state;
			r_timestamp             <= n_timestamp;
		end if;

	end process signals_update;

-------------------------------------------------------------
-- INPUT MONITOR
-------------------------------------------------------------
	input_monitor: process(
	  r_okt_ecu_control_state
	, ecu_req_s
	, r_timestamp
	, IMU_data
	, ECU_fifo_full
	, ECU_n_command
	, horizontal
	, vertical
	, polarity
	, aer_data
	)
	begin
		n_okt_ecu_control_state <= r_okt_ecu_control_state;
		n_timestamp             <= r_timestamp + 1;
		n_ack_n                 <= '1';
		ECU_fifo_w_data             <= (others => '0');
		ECU_fifo_w_en               <= '0';
		IMU_DATA <= (others => '0');

		case r_okt_ecu_control_state is
			when idle =>
				if (ecu_req_s = '0' and ECU_n_command(0) = '1' ) then
					n_okt_ecu_control_state <= req_fall_0;

				elsif (r_timestamp = TIMESTAMP_OVF and ECU_n_command(0) = '1' ) then
					n_okt_ecu_control_state <= timestamp_overflow_0;
				end if;

			when req_fall_0 =>
				if (r_timestamp = TIMESTAMP_OVF) then
					n_okt_ecu_control_state <= timestamp_overflow_0;

				elsif (ECU_fifo_full= '0') then
					ECU_fifo_w_data(TIMESTAMP_BITS_WIDTH - 1 downto 0) <= r_timestamp;
					ECU_fifo_w_en                                      <= '1';
					n_timestamp                                    <= (others => '0');
					n_okt_ecu_control_state                        <= req_fall_1;
				--else
--					n_timestamp                                    <= (others => '0');
--					n_okt_ecu_control_state                        <= req_fall_1;
				end if;

			when req_fall_1 =>
				if (ECU_fifo_full= '0') then
					if (vertical > OFFSET_V or horizontal > OFFSET_H) then
				        IMU_DATA <= (others => '1');
				    else
                        IMU_DATA (0) <= polarity;
                        if (aer_data(30)= '1') then
                            IMU_DATA (9 downto 1) <= horizontal + OFFSET_H;
                        else 
                            IMU_DATA (9 downto 1) <= horizontal;
                        end if;
                        if (aer_data(31)= '1') then
                            IMU_DATA (18 downto 10) <= vertical + OFFSET_V;
                        else
                            IMU_DATA (18 downto 10) <= vertical;
                        end if;     
				    end if;
					ECU_fifo_w_data(BUFFER_BITS_WIDTH - 1 downto 0) <= IMU_data;
					ECU_fifo_w_en                                   <= '1';
					n_okt_ecu_control_state                         <= wait_req_rise;
--				else n_okt_ecu_control_state                         <= wait_req_rise;
				end if;

			when wait_req_rise =>
				n_ack_n <= '0';
				if (ecu_req_s = '1') then
					n_okt_ecu_control_state <= idle;
				end if;

			when timestamp_overflow_0 =>
				if (ECU_fifo_full= '0') then
					ECU_fifo_w_data             <= (others => '1');
					ECU_fifo_w_en               <= '1';
					n_timestamp             <= (others => '0');
					n_okt_ecu_control_state <= timestamp_overflow_1;
				end if;

			when timestamp_overflow_1 =>
				if (ECU_fifo_full= '0') then
					ECU_fifo_w_data             <= (others => '0');
					ECU_fifo_w_en               <= '1';
					n_timestamp             <= (others => '0');
					n_okt_ecu_control_state <= idle;
				end if;
		end case;
	end process;
	
-------------------------------------------------------------
-- CONTROL USB_READY
-------------------------------------------------------------
	control_ECU_usb_ready : process(clk, rst_n) is
	   variable usb_burst : integer;
	begin
		if rst_n = '0' then
			ECU_usb_ready <= '0';
			usb_burst := 0;
			ECU_fifo_r_en_end <= '0';
			ECU_fifo_r_en_latched <= '0';
			
		elsif rising_edge(clk) then
		   ECU_fifo_r_en_latched <= ECU_fifo_r_en;
		    
			if ECU_fifo_r_en_latched = '1' and ECU_fifo_r_en = '0' then
				ECU_fifo_r_en_end <= '1';
		   else
		      ECU_fifo_r_en_end <= '0';
		   end if;
			
			if ECU_fifo_fill_count > FIFO_ALM_EMPTY_OFFSET then
				ECU_usb_ready <= '1';
				usb_burst := USB_BURST_WORDS;
			elsif ECU_usb_ready = '1' then
			    usb_burst := usb_burst - 1;
			    if usb_burst = 0 or ECU_fifo_r_en_end = '1' then
			        ECU_usb_ready <= '0';
			    end if;
			end if;
		end if;
	end process;

end Behavioral;

