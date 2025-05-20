library ieee;
use ieee.STD_LOGIC_1164.all;
use work.okt_global_pkg.all;

package okt_osu_pkg is
	constant OSU_FIFO_DEPTH            : integer := 16*1024; -- 4 bytes words
	constant USB_BURST_WORDS           : integer := 1024;
   constant TIMESTAMP_OVF       		  : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0) := (others => '1');



end okt_osu_pkg;

package body okt_osu_pkg is
end okt_osu_pkg;
