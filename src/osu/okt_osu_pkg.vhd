library ieee;
use ieee.STD_LOGIC_1164.all;
use work.okt_global_pkg.all;

package okt_osu_pkg is
	constant OSU_FIFO_DEPTH            : integer := 16*1024; -- 4 bytes words
	constant NODE_IN_DATA_BITS_WIDTH   : integer := 32; -- 28?
	constant COMMAND_BIT_WIDTH 		  : integer := 3;
	constant USB_BURST_WORDS           : integer := 4*1024;


end okt_osu_pkg;

package body okt_osu_pkg is
end okt_osu_pkg;
