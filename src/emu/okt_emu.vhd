
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.okt_emu_pkg.all;
use work.global_pkg.all;

entity okt_emu is -- Event Monitor Unit
	Port(
		clk       : in  std_logic;
		rst_n     : in  std_logic;
		req_n     : in  std_logic;
		aer_data  : in  std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		ack_n     : out std_logic;
		out_data  : out std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		out_valid : out std_logic;
		status    : out std_logic
	 );
end okt_emu;

architecture Behavioral of okt_emu is

	type state is (idle, wait_event, req_fall_0, req_fall_1, wait_req_rise, timestamp_overflow_0, timestamp_overflow_1);
	signal r_okt_emnu_control_state, n_okt_emnu_control_state : state;
	
	signal r_timestamp, n_timestamp : std_logic_vector (TIMESTAMP_BITS_WIDTH-1 downto 0);	
	signal r_out_data, n_out_data	: std_logic_vector (BUFFER_BITS_WIDTH-1 downto 0);
	signal n_out_valid				: std_logic;
	signal n_ack_n					: std_logic;
		
begin
	
	status <= not n_ack_n;
	
	signals_update : process (clk, rst_n)
	begin
		if rst_n = '0' then
			r_okt_emnu_control_state 	<= idle;
			r_timestamp					<= (others=>'0');
			r_out_data					<= (others=>'0');
					
		elsif rising_edge(clk) then
			r_okt_emnu_control_state 	<= n_okt_emnu_control_state;
			r_timestamp					<= n_timestamp;
			r_out_data					<= n_out_data;
		end if;
		
	end process signals_update;
	
	
	process (r_okt_emnu_control_state, req_n, r_timestamp, aer_data, r_out_data)
	begin
		n_okt_emnu_control_state 	<= r_okt_emnu_control_state;
		n_timestamp					<= r_timestamp + 1;
		n_out_data					<= r_out_data;
		n_out_valid					<= '0';
		n_ack_n						<= '1';
		
		case r_okt_emnu_control_state is
			when idle =>
				n_okt_emnu_control_state <= wait_event;
				
			when wait_event =>				
				if(req_n = '0') then
					n_okt_emnu_control_state <= req_fall_0;
				
				elsif(r_timestamp = TIMESTAMP_OVF) then
					n_okt_emnu_control_state <= timestamp_overflow_0;
				end if;
				
			when req_fall_0 =>
				n_out_data(TIMESTAMP_BITS_WIDTH-1 downto 0)	<=  r_timestamp;
				n_out_valid									<= '1';
				n_timestamp									<= (others=>'0');
				n_okt_emnu_control_state					<= req_fall_1;
				
			when req_fall_1 =>
				n_out_data(BUFFER_BITS_WIDTH-1 downto 0) 	<=  aer_data;
				n_out_valid									<= '1';
				n_timestamp									<= (others=>'0');
				n_ack_n										<= '0';
				n_okt_emnu_control_state 					<= wait_req_rise;
				
			when wait_req_rise =>
				n_ack_n							<= '0';
				if(req_n = '1') then
					n_okt_emnu_control_state	<= wait_event;
				end if;
				
			when timestamp_overflow_0 =>
				n_out_data					<= (others=>'1');
				n_out_valid					<= '1';
				n_timestamp					<= (others=>'0');
				n_okt_emnu_control_state 	<= timestamp_overflow_1;
				
			when timestamp_overflow_1 =>
				n_out_data					<= (others=>'0');
				n_out_valid					<= '1';
				n_timestamp					<= (others=>'0');
				n_okt_emnu_control_state	<= wait_event;
			
		end case;
	
	end process;
	
	
	process(n_out_data, n_out_valid, n_ack_n)
	begin
		out_data  	<= n_out_data;
		out_valid 	<= n_out_valid;
		ack_n		<= n_ack_n;
	end process;
end Behavioral;


