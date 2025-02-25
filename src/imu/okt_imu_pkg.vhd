
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.math_real.all;

package okt_imu_pkg is
    constant NUM_INPUTS       : integer := 4;
    constant INPUT_BITS_WIDTH : integer := integer(ceil(log2(real(NUM_INPUTS))));
--    constant OFFSET_H         : integer := 198;
--    constant OFFSET_V         : integer := 152;
end okt_imu_pkg;

package body okt_imu_pkg is

end okt_imu_pkg;
