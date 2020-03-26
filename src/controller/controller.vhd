----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:00:08 04/14/2019 
-- Design Name: 
-- Module Name:    controller - Behavioral 
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.global_pkg.ALL;
use work.controller_pkg.ALL;
use work.merger_pkg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity controller is
    Port ( 
		CLK 			: in  STD_LOGIC;
		RST 			: in  STD_LOGIC;
		
		REQ_MER 		: in  STD_LOGIC;
		ACK_MER 		: out  STD_LOGIC;
		
		STATUS_MON 	: in  STD_LOGIC;
		STATUS_MER 	: in  STD_LOGIC;
		STATUS_LOG 	: in  STD_LOGIC;
		STATUS_PAS 	: in  STD_LOGIC;
		
		CONTROL 		: in  STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
		
		REQ_MON 		: out  STD_LOGIC;
		ACK_MON 		: in  STD_LOGIC;
		REQ_PAS 		: out  STD_LOGIC;
		ACK_PAS 		: in  STD_LOGIC;
		REQ_LOG 		: out  STD_LOGIC;
		ACK_LOG 		: in  STD_LOGIC;
		
		MERGER_SEL	: out STD_LOGIC_VECTOR (INPUT_NUMBER-1 downto 0);
		
		LOG_PLAY		: out STD_LOGIC;
		
		STATUS 		: out  STD_LOGIC_VECTOR (LED_BUS_WIDTH-1 downto 0)
			);
end controller;

architecture Behavioral of controller is
	
	signal merge_sel_n	:	STD_LOGIC_VECTOR (INPUT_NUMBER-1 downto 0);
	signal mode_sel_n		:	STD_LOGIC_VECTOR (MODE_BUS_WIDTH-1 downto 0);
	
begin

	crtl_signals : process (CONTROL)
	begin
		merge_sel_n 	<= CONTROL(INPUT_NUMBER-1 downto 0);
		mode_sel_n		<= CONTROL(INPUT_NUMBER+MODE_BUS_WIDTH-1 downto INPUT_NUMBER);
	end process;



	ack_management : process (RST, CLK)
	begin
		if RST = '0' then
			ACK_MER		<= '1';
			
		elsif rising_edge(CLK) then
			if ACK_PAS = 'Z' then
				ACK_MER	<= ACK_LOG and ACK_MON;
			else
				ACK_MER	<= ACK_LOG and ACK_MON and ACK_PAS;
			end if;
		end if;
	end process ack_management;
	
	
	
	update_registers : process (RST, CLK)
	begin
		if RST = '0' then
			MERGER_SEL 	<= (others=>'0');
			STATUS		<= (others=>'0');
			REQ_MON		<= '1';
			REQ_LOG		<= '1';
			REQ_PAS		<= '1';
			LOG_PLAY		<= '0';
			
		elsif rising_edge(CLK) then
			MERGER_SEL 	<= merge_sel_n;
			
			if mode_sel_n(0) = '1' then
				REQ_MON <= REQ_MER;
			else
				REQ_MON <= '1';
			end if;
			if mode_sel_n(1) = '1' then
				REQ_PAS <= REQ_MER;
			else
				REQ_PAS <= '1';
			end if;
			if mode_sel_n(2) = '1' then
				REQ_LOG <= REQ_MER;
			else
				REQ_LOG <= '1';
			end if;
			
			LOG_PLAY 	<= mode_sel_n(3);
			STATUS(0)	<= STATUS_MER;
			STATUS(1)	<= STATUS_MON;
			STATUS(2)	<= STATUS_PAS;
			STATUS(3)	<= STATUS_LOG;
			
		end if;
	end process;

end Behavioral;

