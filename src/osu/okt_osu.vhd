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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity okt_osu is						-- Output Sequencer Unit
    Port ( clk   			: in  STD_LOGIC;
           rst_n 			: in  STD_LOGIC;
           aer_data  	: in  STD_LOGIC_VECTOR (BUFFER_BITS_WIDTH - 1 downto 0);
           req_n 			: in  STD_LOGIC;
           ack_n 			: inout  STD_LOGIC;
           osu_cmd 		: in  STD_LOGIC_VECTOR (1 downto 0);
           osu_data 		: out  STD_LOGIC;
           osu_req_n 	: out  STD_LOGIC;
           osu_ack_n 	: in  STD_LOGIC
	);
end okt_osu;

architecture Behavioral of okt_osu is

begin


end Behavioral;

