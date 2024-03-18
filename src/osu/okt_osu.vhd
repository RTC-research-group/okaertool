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

	--Bit Masking for OutputMux
	constant Mask_MON     :    std_logic_vector(2 downto 0):="001";
	constant Mask_PASS    :    std_logic_vector(2 downto 0):="010";
	constant Mask_PASSMON :    std_logic_vector(2 downto 0):="011";
	constant Mask_SEQ     :    std_logic_vector(2 downto 0):="100";
	
	-- FIFO signals
	signal fifo_w_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_w_en   		  : std_logic;
	signal fifo_r_data 		  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal fifo_r_en   		  : std_logic;
	signal fifo_empty  		  : std_logic;
	signal fifo_full   		  : std_logic;
	signal fifo_almost_full   : std_logic;
	
	signal usb_ready 			  : std_logic;
	signal fifo_w_en_end 	  : std_logic; 
   signal fifo_w_en_latched  : std_logic;
	
	--Sys signals
	signal n_command: std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	signal ecu_node_ack_n : std_logic := '1'; --Latched signal
	
	signal out_req: std_logic := '1'; --output request
	signal out_ack: std_logic := '1'; --output ack
	signal aer_data: std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	
	
	signal r_timestamp, n_timestamp, Limit_ts : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0);
	type state is (idle, timestamp_set, timestamp_check, wait_ack_rise, data_trigger_0, data_trigger_1, discard_aer);
	signal r_okt_osu_control_state, n_okt_osu_control_state : state;

begin

	n_command <= cmd;
	status <= "00000" & usb_ready & fifo_empty & fifo_full;
	
		sequencer_fifo : entity work.okt_fifo
		generic map(
			DEPTH => OSU_FIFO_DEPTH
		)
		port map(
			clk    => clk,
			rst_n  => rst_n,
			w_data => fifo_w_data,
			w_en   => fifo_w_en,
			r_data => fifo_r_data,
			r_en   => fifo_r_en,
			empty  => fifo_empty,
			full   => fifo_full,
			almost_full => fifo_almost_full
		);
		
			fifo_w_data  <= in_data;
		   fifo_w_en <= in_wr;
		   in_ready <= usb_ready;
			

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
	 
      when "001" => --State MON switches off output and connects its EMU_ACK to IMU_ACK
			ecu_node_out_ack_n <= ecu_in_ack_n;

      when "010" => --State PASS bypasses output and connects OUT_ACK to IMU_ACK
			ecu_node_out_ack_n <= node_in_osu_ack_n;
			node_in_data <= aer_in_data;
			node_req_n <= req_in_data_n;

      when "011" => --State MON_AND_PASS bypasses output and connects OUT_ACK and EMU_ACK to IMU_ACK via or gate
			ecu_node_out_ack_n <= ecu_node_ack_n;
			node_in_data <= aer_in_data;
			node_req_n <= req_in_data_n;

		when "100" =>
			node_in_data <= aer_data;
			node_req_n <= out_req;
			out_ack <= node_in_osu_ack_n;

      when others => --TODO
		
    end case;
  end if;
end process;

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
--From here on, sequencer code is written. ALPHA VER.
--------------------------------------------------------------------------------------------------------------------

-- signals_update: This process will update the control_state and timestamp signals
signals_update : process(clk, rst_n)
begin
	if rst_n = '0' then
		r_okt_osu_control_state <= idle;
		r_timestamp             <= (others => '0');
	
	elsif rising_edge(clk) then
		r_okt_osu_control_state <= n_okt_osu_control_state;
		r_timestamp             <= n_timestamp;
	end if;
end process;

-- Take data from FIFO - REVISAR
output_sequencer: process(r_okt_osu_control_state, r_timestamp, out_ack, fifo_r_data, fifo_empty, n_command, Limit_ts)
begin
	-- Me faltan inicializaciones? estados?
	n_okt_osu_control_state <= r_okt_osu_control_state;
	n_timestamp             <= r_timestamp + 1;
	fifo_r_en               <= '0';
	Limit_ts						<= (others => '0');
	aer_data						<= (others => '0');
	out_req						<= '1';

	case r_okt_osu_control_state is
		when idle => --En idle se espera a que ACK sea 1 y CMD sea 100. Si es así, se pasa a Timestamp_set_0
			if (out_ack = '1' and n_command(2) = '1' ) then								--if ready_to_send
				n_okt_osu_control_state 	<= timestamp_set;								--next state
			end if;

		when timestamp_set => -- Se lee el timestamp de la FIFO y se guarda en r_timestamp. Se pone REQ a 1 y se pasa a timestamp_set_1
			if (fifo_empty = '0') then															--if fifo_not_empty
				--n_timestamp                      <= (others => '0');					--reset count
				n_okt_osu_control_state          <= timestamp_check;					--next state
			end if;

		when timestamp_check => --Aqui se espera a que Timestamp sea 0. Cuando lo sea, se pasa a data_trigger.
			Limit_ts <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0); 						--set limit
			
			if (Limit_ts = x"FFFFFFFF") then									--else if limit=overflow
				fifo_r_en                                   	<= '1';							--read new fifo bank
				aer_data 												<= (others => '0');										--reset output
				n_okt_osu_control_state 							<= discard_aer;							--state idle
			
			elsif (r_timestamp + 2 > Limit_ts) then									--if limit_reached
				fifo_r_en                                   	<= '1';							--read new fifo bank
				n_okt_osu_control_state                     	<= data_trigger_0;						--next state
				n_timestamp                      <= (others => '0');					--reset count
			end if;

		when data_trigger_0 => -- Aqui se pone REQ a 0 y se dispara el dato										--if ack_fall
			n_okt_osu_control_state <= data_trigger_1;								--next state
			--n_timestamp                      <= (others => '0');					--reset count

		when data_trigger_1 => -- Aqui se pone REQ a 0 y se dispara el dato
			aer_data <= fifo_r_data(BUFFER_BITS_WIDTH - 1 downto 0)  ;						--set output
			out_req <= '0';												-- request fall
			if (out_ack = '0') then											--if ack_fall
				n_okt_osu_control_state <= wait_ack_rise;								--next state
				fifo_r_en                                   <= '1';							--read new fifo bank
			end if;
			
		when wait_ack_rise =>
			out_req<= '1';												--request rise
			aer_data             	<= (others => '0');									--reset output
			if (out_ack = '1') then												--if ack_rise
				n_okt_osu_control_state <= idle;										--state_idle
			end if;

		when discard_aer =>
			aer_data             	<= (others => '0');									--reset output
			fifo_r_en                                   <= '1';
			n_okt_osu_control_state <= idle;										--state_idle

	end case;
end process;
	

--Control USB: REVISAR
control_usb_ready : process(clk, rst_n) is
	variable usb_burst : integer;
begin
	if rst_n = '0' then --RESET
		usb_ready <= '0';
		usb_burst := 0;
		fifo_w_en_end <= '0';
		fifo_w_en_latched <= '0';
		
	elsif rising_edge(clk) then --NORMAL
		 fifo_w_en_latched <= fifo_w_en;									-- latched = enable	
		if fifo_w_en_latched = '1' and fifo_w_en = '0' then							-- if latched = 1 and enable = 0
			  fifo_w_en_end <= '1';											-- end = 1
		 else													-- else
			  fifo_w_en_end <= '0';											-- end = 0
		 end if;
		if fifo_empty = '1' then 							-- if fifo_empty
			usb_ready <= '1';											-- ready = 1
			usb_burst := USB_BURST_WORDS;										-- burst = 4096
		elsif usb_ready = '1' then										-- else if ready = 1
			 usb_burst := usb_burst - 1;										-- burst - 1
			 if usb_burst = 0 or fifo_w_en_end = '1' then								-- if burst = 0 or end = 1
				  usb_ready <= '0';											-- ready = 0
			 end if;
		end if;
	end if;
end process;
	
	
end Behavioral;

