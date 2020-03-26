----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:58:58 04/19/2019 
-- Design Name: 
-- Module Name:    okaertools - Behavioral 
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
use work.global_pkg.all;
use work.FRONTPANEL.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity okaertools is
	port (
		--SYS_CLKP  		: in     STD_LOGIC;
		--SYS_CLKN  		: in     STD_LOGIC;
				
		-- USB 3.0 interface
		okUH      		: in     STD_LOGIC_VECTOR(USB_UH_WIDTH_BUS-1 downto 0);
		okHU      		: out    STD_LOGIC_VECTOR(USB_HU_WIDTH_BUS-1 downto 0);
		okUHU     		: inout  STD_LOGIC_VECTOR(USB_UHU_WIDTH_BUS-1 downto 0);
		okAA      		: inout  STD_LOGIC;
		
		-- AER interfaces
		ROME_A_DATA		: in std_logic_vector(ROME_DATA_WIDTH-1 downto 0);
		ROME_A_REQ		: in std_logic;
		ROME_A_ACK		: out std_logic;
		
		ROME_B_DATA		: in std_logic_vector(ROME_DATA_WIDTH-1 downto 0);
		ROME_B_REQ		: in std_logic;
		ROME_B_ACK		: out std_logic;
		
		NODE_DATA		: in std_logic_vector(NODE_DATA_WIDTH-1 downto 0);
		NODE_REQ			: in std_logic;
		NODE_ACK			: out std_logic;
		
		SPINNAKER_DATA	: in std_logic_vector(SPINNAKER_DATA_WIDTH-1 downto 0);
		SPINNAKER_REQ	: in std_logic;
		SPINNAKER_ACK	: out std_logic;
		
		OUT_DATA			: out std_logic_vector(NODE_DATA_WIDTH-1 downto 0);
		OUT_REQ			: out std_logic;
		OUT_ACK			: in std_logic;
		
		-- Status leds
		LEDS      		: out    STD_LOGIC_VECTOR(LEDS_WIDTH_BUS-1 downto 0)
	);
end okaertools;

architecture Behavioral of okaertools is


	signal okClk      			: STD_LOGIC;
	signal okHE       			: STD_LOGIC_VECTOR(112 downto 0);
	signal okEH       			: STD_LOGIC_VECTOR(64 downto 0);
	signal okEHx      			: STD_LOGIC_VECTOR(65*5-1 downto 0);

	signal ep00wire   			: STD_LOGIC_VECTOR(BUFFER_WIDTH-1 downto 0);
	
	signal rome_a_req_latch_0	: STD_LOGIC;
	signal rome_a_req_latch_1	: STD_LOGIC;
	signal rome_b_req_latch_0	: STD_LOGIC;
	signal rome_b_req_latch_1	: STD_LOGIC;
	signal node_req_latch_0		: STD_LOGIC;
	signal node_req_latch_1		: STD_LOGIC;
	signal spinn_req_latch_0	: STD_LOGIC;
	signal spinn_req_latch_1	: STD_LOGIC;
	signal out_ack_latch_0		: STD_LOGIC;
	signal out_ack_latch_1		: STD_LOGIC;

begin

	-- Sync input signals
	syncronizer: process(okClk, rst)
		begin
			if (rst = '0') then
				

			elsif rising_edge(okClk) then
				
				
			end if;
	end process;

	---TODO seguir por aquí---
	okHI : okHost port map (
		okUH=>okUH, 
		okHU=>okHU, 
		okUHU=>okUHU, 
		okAA=>okAA,
		okClk=>okClk, 
		okHE=>okHE, 
		okEH=>okEH
	);
	
	wi00 : okWireIn port map (
		okHE=>okHE,
		ep_addr=>x"00",
		ep_dataout=>ep00wire
	);
	
	
	

end Behavioral;