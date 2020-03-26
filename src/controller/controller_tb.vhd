--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:01:33 04/16/2019
-- Design Name:   
-- Module Name:   /home/arios/Projects/okaertools/src/controller/controller_tb.vhd
-- Project Name:  okaertools
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: controller
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY controller_tb IS
END controller_tb;
 
ARCHITECTURE behavior OF controller_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT controller
    PORT(
         CLK 			: IN  std_logic;
         RST 			: IN  std_logic;
         REQ_MER 		: IN  std_logic;
         ACK_MER 		: OUT  std_logic;
         STATUS_MON 	: IN  std_logic;
         STATUS_MER 	: IN  std_logic;
         STATUS_LOG 	: IN  std_logic;
         STATUS_PAS 	: IN  std_logic;
         CONTROL 		: IN  std_logic_vector(31 downto 0);
         REQ_MON 		: OUT  std_logic;
         ACK_MON 		: IN  std_logic;
         REQ_PAS 		: OUT  std_logic;
         ACK_PAS 		: IN  std_logic;
         REQ_LOG 		: OUT  std_logic;
         ACK_LOG 		: IN  std_logic;
         MERGER_SEL 	: OUT  std_logic_vector(4 downto 0);
         LOG_PLAY 	: OUT  std_logic;
         STATUS 	: OUT  std_logic_vector(6 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK 			: std_logic := '0';
   signal RST 			: std_logic := '0';
   signal REQ_MER 	: std_logic := '0';
   signal STATUS_MON : std_logic := '0';
   signal STATUS_MER : std_logic := '0';
   signal STATUS_LOG : std_logic := '0';
   signal STATUS_PAS : std_logic := '0';
   signal CONTROL 	: std_logic_vector(31 downto 0) := (others => '0');
   signal ACK_MON 	: std_logic := '0';
   signal ACK_PAS 	: std_logic := '0';
   signal ACK_LOG 	: std_logic := '0';

 	--Outputs
   signal ACK_MER 	: std_logic;
   signal REQ_MON 	: std_logic;
   signal REQ_PAS 	: std_logic;
   signal REQ_LOG 	: std_logic;
   signal MERGER_SEL : std_logic_vector(4 downto 0);
   signal LOG_PLAY 	: std_logic;
   signal STATUS 		: std_logic_vector(6 downto 0);

   -- Clock period definitions
   constant CLK_period : time := 10 ns;

	type state is (idle, req_fall, req_rise);
	signal current_state, next_state : state;
	
	signal ack_blocked : std_logic := '0';
	
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: controller PORT MAP (
          CLK 			=> CLK,
          RST 			=> RST,
          REQ_MER 	=> REQ_MER,
          ACK_MER 	=> ACK_MER,
          STATUS_MON => STATUS_MON,
          STATUS_MER => STATUS_MER,
          STATUS_LOG => STATUS_LOG,
          STATUS_PAS => STATUS_PAS,
          CONTROL 	=> CONTROL,
          REQ_MON 	=> REQ_MON,
          ACK_MON 	=> ACK_MON,
          REQ_PAS 	=> REQ_PAS,
          ACK_PAS		=> ACK_PAS,
          REQ_LOG 	=> REQ_LOG,
          ACK_LOG 	=> ACK_LOG,
          MERGER_SEL => MERGER_SEL,
          LOG_PLAY 	=> LOG_PLAY,
          STATUS 		=> STATUS
        );



   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 


   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	
		RST <= '0';
      wait for CLK_period*10;
		RST <= '1';
      -- insert stimulus here
		-- CONTROL signal meaning
		-- bit 0-4 input selection (0->rome_a; 1->rome_b; 2->node_out; 3->logger; 4->spinnaker)
		-- bit 5-8 action to do (5->monitor; 6->Passthrough; 7->Logger; 8->Player)
		CONTROL(4 downto 0)	<= b"00001";
		CONTROL(8 downto 5)	<= b"0001";
		wait for CLK_period*40;
		CONTROL(4 downto 0)	<= b"11111";
		CONTROL(8 downto 5)	<= b"1111";
		wait for CLK_period*5;
		ack_blocked				<= '1';
		wait for CLK_period*3;
		ack_blocked				<= '0';
      wait;
   end process;



	signals_update : process (CLK, RST)
	begin
		if RST = '0' then
			current_state <= idle;
			
		elsif rising_edge(CLK) then
			current_state 	<= next_state;
		end if;
	end process;
	
	
	
	FSM_transition : process (current_state, ACK_MER)
	begin
		next_state 	<= current_state;
		REQ_MER		<= '1';
		
		case current_state is
			when idle =>
				if ACK_MER = '1' then
					next_state <= req_fall;
				end if;
				
			when req_fall =>
				REQ_MER			<= '0';
				if ACK_MER = '0' then
					next_state 	<= req_rise;
				end if;
			
			when req_rise =>
				REQ_MER		<= '1';
				next_state 	<= idle;
					
			when others =>
				next_state 	<= idle;
		end case;
	end process;
	
	
	ACK_generation : process (RST, CLK)
	begin
		if RST = '0' then
			ACK_LOG	<= '1';
			ACK_MON	<= '1';
			ACK_PAS	<= '1';
			
		elsif rising_edge(CLK) then
			if REQ_LOG = '0' then
				ACK_LOG	<= '0';
			else
				ACK_LOG	<= '1';
			end if;
			if REQ_MON = '0' then
				ACK_MON	<= '0';
			else
				if ack_blocked = '0' then
					ACK_MON	<= '1';
				end if;
			end if;
			if REQ_PAS = '0' then
				ACK_PAS	<= '0';
			else
				ACK_PAS	<= '1';
			end if;
		end if;
	end process;
	
END;
