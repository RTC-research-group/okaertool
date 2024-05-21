library ieee;
use ieee.STD_LOGIC_1164.all;
use work.okt_global_pkg.all;

package okt_ecu_pkg is
    constant FIFO_DEPTH           : integer                                             := 16*1024; -- 4 bytes words
    constant TIMESTAMP_OVF        : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0) := (others => '1');
    constant USB_BURST_WORDS      : integer                                             := 256;
	 constant COMMAND_BIT_WIDTH 	 : integer 															 := 3;
end okt_ecu_pkg;

package body okt_ecu_pkg is
end okt_ecu_pkg;
