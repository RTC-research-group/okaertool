
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY okt_emu_tb IS
END okt_emu_tb;
 
ARCHITECTURE behavior OF okt_emu_tb IS 

   --Inputs
	signal clk      : std_logic                     := '0';
	signal rst_n    : std_logic                     := '0';
	signal req_n    : std_logic                     := '0';
	signal aer_data : std_logic_vector(31 downto 0) := (others => '0');

	signal aer_data_r : std_logic_vector(31 downto 0) := (others => '0');
	signal force_ovf  : std_logic;

	--Outputs
	signal ack_n     : std_logic;
	signal out_data  : std_logic_vector(31 downto 0);
	signal out_valid : std_logic;
	signal status    : std_logic;

	-- Clock period definitions
	constant CLK_period : time := 20 ns;

	type state is (idle, req_fall, req_rise);
	signal current_state, next_state : state;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.okt_emu PORT MAP (
          clk => clk,
          rst_n => rst_n,
          req_n => req_n,
          aer_data => aer_data,
          ack_n => ack_n,
          out_data => out_data,
          out_valid => out_valid,
          status => status
        );

   -- Clock process definitions
   CLK_process :process
   begin
		clk <= '0';
		wait for CLK_period/2;
		clk <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;
		force_ovf <= '0';
		rst_n <= '0';
      wait for CLK_period*10;
		rst_n <= '1';
      -- insert stimulus here
		
		wait for 500 us;
		force_ovf <= '1';
		wait for 2 ms;
		force_ovf <= '0';
		
      wait;
   end process;

	signals_update : process (clk, rst_n)
	begin
		if rst_n = '0' then
			current_state <= idle;
			
		elsif rising_edge(clk) then
			current_state 	<= next_state;
			
			if req_n = '1' and ack_n = '0' then
				aer_data_r <= aer_data_r + 1;
			end if;
		end if;
	end process;
	
	FSM_transition : process (current_state, aer_data_r, ack_n, force_ovf)
	begin
		next_state 	<= current_state;
		req_n			<= '1';
		aer_data	 	<= (others=>'0');
		
		case current_state is
			when idle =>
				if ack_n = '1' and force_ovf = '0' then
					next_state <= req_fall;
				end if;
				
			when req_fall =>
				req_n 			<= '0';
				aer_data 	<= aer_data_r;
				if ack_n = '0' then
					next_state 	<= req_rise;
				end if;
			
			when req_rise =>
				req_n 			<= '1';
				next_state 	<= idle;
					
		end case;
	end process;

END;
