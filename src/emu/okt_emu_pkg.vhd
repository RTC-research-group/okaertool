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
use work.global_pkg.all;

package okt_emu_pkg is

	constant TIMESTAMP_BITS_WIDTH		:	integer := 10;--BUFFER_BITS_WIDTH;
	constant TIMESTAMP_OVF				:	std_logic_vector(TIMESTAMP_BITS_WIDTH-1 downto 0) := (others=>'1');

end okt_emu_pkg;

package body okt_emu_pkg is

end okt_emu_pkg;
