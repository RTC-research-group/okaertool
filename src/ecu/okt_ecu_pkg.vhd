library ieee;
use ieee.STD_LOGIC_1164.all;
use work.okt_global_pkg.all;

package okt_ecu_pkg is
    constant TIMESTAMP_OVF         : std_logic_vector(TIMESTAMP_BITS_WIDTH - 1 downto 0) := (others => '1');
    constant FIFO_DEPTH            : integer                                             := 32 * 1024; -- 4 bytes words
    constant FIFO_ALM_FULL_OFFSET  : integer                                             := 16 * 1024;
    constant FIFO_ALM_EMPTY_OFFSET : integer                                             := 1024;
    constant USB_BURST_WORDS       : integer                                             := 1024; -- Must be equal to FIFO_ALM_EMPTY_OFFSET
end okt_ecu_pkg;

package body okt_ecu_pkg is
end okt_ecu_pkg;
