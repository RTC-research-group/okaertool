--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.math_real.all;

package global_pkg is

	constant BUFFER_BITS_WIDTH			: integer := 32;
	constant ROME_DATA_BITS_WIDTH		: integer := 16;
	constant NODE_DATA_BITS_WIDTH		: integer := 28;
	constant SPINNAKER_BITS_DATA_WIDTH	: integer := 8;
	constant NUM_INPUTS					: integer := 5;
	constant INPUT_BITS_WIDTH			: integer := integer(ceil(log2(real(NUM_INPUTS))));
	
--	component controller port
--		(
--			CLK 			: in  STD_LOGIC;
--			RST 			: in  STD_LOGIC;
--			
--			REQ_MER 		: in  STD_LOGIC;
--			ACK_MER 		: out  STD_LOGIC;
--			
--			STATUS_MON 		: in  STD_LOGIC;
--			STATUS_MER 		: in  STD_LOGIC;
--			STATUS_LOG 		: in  STD_LOGIC;
--			STATUS_PAS 		: in  STD_LOGIC;
--			
--			CONTROL 		: in  STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
--			
--			REQ_MON 		: out  STD_LOGIC;
--			ACK_MON 		: in  STD_LOGIC;
--			REQ_PAS 		: out  STD_LOGIC;
--			ACK_PAS 		: in  STD_LOGIC;
--			REQ_LOG 		: out  STD_LOGIC;
--			ACK_LOG 		: in  STD_LOGIC;
--			
--			MERGER_SEL		: out STD_LOGIC_VECTOR (INPUT_NUMBER-1 downto 0);
--			
--			LOG_PLAY		: out STD_LOGIC;
--			
--			STATUS 			: out  STD_LOGIC_VECTOR (LED_BUS_WIDTH-1 downto 0)
--		);
--	end component;
--	
--	component merger port
--		(
--			CLK				: in std_logic;
--			RST				: in std_logic;
--			
--			ROME_A_DATA		: in std_logic_vector(ROME_DATA_WIDTH-1 downto 0);
--			ROME_A_REQ		: in std_logic;
--			ROME_A_ACK		: out std_logic;
--			
--			ROME_B_DATA		: in std_logic_vector(ROME_DATA_WIDTH-1 downto 0);
--			ROME_B_REQ		: in std_logic;
--			ROME_B_ACK		: out std_logic;
--			
--			NODE_DATA		: in std_logic_vector(NODE_DATA_WIDTH-1 downto 0);
--			NODE_REQ			: in std_logic;
--			NODE_ACK			: out std_logic;
--			
--			SPINNAKER_DATA	: in std_logic_vector(SPINNAKER_DATA_WIDTH-1 downto 0);
--			SPINNAKER_REQ	: in std_logic;
--			SPINNAKER_ACK	: out std_logic;
--			
--			LOGGER_DATA		: in std_logic_vector(BUFFER_WIDTH-1 downto 0);
--			LOGGER_REQ		: in std_logic;
--			LOGGER_ACK		: out std_logic;
--			
--			INPUT_SELECT	: in std_logic_vector(INPUT_NUMBER-1 downto 0);
--			
--			OUT_DATA			: out std_logic_vector(BUFFER_WIDTH-1 downto 0);
--			OUT_REQ			: out std_logic;
--			OUT_ACK			: in std_logic;
--			
--			STATUS 			: out STD_LOGIC
--		);
--	end component;
	
end global_pkg;


package body global_pkg is
 
end global_pkg;
