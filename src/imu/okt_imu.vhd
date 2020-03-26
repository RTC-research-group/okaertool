----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:24:06 03/16/2019 
-- Design Name: 
-- Module Name:    merger - Behavioral 
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
use IEEE.STD_LOGIC_1164.all;
use work.okt_imu_pkg.all;
use work.global_pkg.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity okt_imu is	-- Input Merger Unit
	Port(
		clk			 : in  std_logic;
		rst_n        : in  std_logic;
		in0_data	 : in  std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
		in0_req_n    : in  std_logic;
		in0_ack_n    : out std_logic;
		in1_data	 : in  std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
		in1_req_n	 : in  std_logic;
		in1_ack_n	 : out std_logic;
		in2_data	 : in  std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
		in2_req_n    : in  std_logic;
		in2_ack_n    : out std_logic;
		in3_data	 : in  std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
		in3_req_n	 : in  std_logic;
		in3_ack_n	 : out std_logic;
		in4_data	 : in  std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
		in4_req_n	 : in  std_logic;
		in4_ack_n    : out std_logic;
		input_select : in  std_logic_vector(NUM_INPUTS-1 downto 0);
		out_data     : out std_logic_vector(BUFFER_BITS_WIDTH-1 downto 0);
		out_req_n    : out std_logic;
		out_ack      : in  std_logic;
		status       : out STD_LOGIC
	);
end okt_imu;

architecture RTL of okt_imu is

	type state is (idle, wait_input, in0, in1, in2, in3, in4);
	signal r_okt_control_state, n_okt_control_state : state;

begin

	process(clk, rst_n)
	begin
		if rst_n = '0' then
			r_okt_control_state <= idle;

		elsif rising_edge(clk) then
			r_okt_control_state <= n_okt_control_state;

		end if;

	end process;

	
	process(r_okt_control_state, input_select,
								in0_req_n, in1_req_n, in2_req_n, in3_req_n, in4_req_n, 
								in0_data, in1_data, in2_data, in4_data, in3_data, 
								out_ack
	)
	begin
		n_okt_control_state <= r_okt_control_state;
		in0_ack_n 			<= '1';
		in1_ack_n 			<= '1';
		in2_ack_n 			<= '1';
		in3_ack_n 			<= '1';
		in4_ack_n 			<= '1';
		out_data  			<= (others => '0');
		out_req_n 			<= '1';
		status				<= not out_ack;

		case r_okt_control_state is
			when idle =>
				n_okt_control_state	<= wait_input;
				
			when wait_input =>
				if(input_select(0) = '1' and in0_req_n = '0') then
					n_okt_control_state <= in0;

				elsif(input_select(1) = '1' and in1_req_n = '0') then
					n_okt_control_state <= in1;

				elsif(input_select(2) = '1' and in2_req_n = '0') then
					n_okt_control_state <= in2;

				elsif(input_select(3) = '1' and in3_req_n = '0') then
					n_okt_control_state <= in3;

				elsif(input_select(4) = '1' and in4_req_n = '0') then
					n_okt_control_state <= in4;
				end if;

			when in0 =>
				out_data(BUFFER_BITS_WIDTH-1 downto BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH) <= std_logic_vector(to_unsigned(0, INPUT_BITS_WIDTH));
				out_data(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0)             	<= in0_data;
				out_req_n                                          						<= in0_req_n;
				in0_ack_n                                          						<= out_ack;
				
				if(input_select = std_logic_vector(to_unsigned(0,input_select'length))) then
					n_okt_control_state <= idle;

				elsif (in0_req_n = '1' and out_ack = '1') then
					if input_select(1) = '1' and in1_req_n = '0' then
						n_okt_control_state <= in1;

					elsif input_select(2) = '1' and in2_req_n = '0' then
						n_okt_control_state <= in2;

					elsif input_select(3) = '1' and in3_req_n = '0' then
						n_okt_control_state <= in3;

					elsif input_select(4) = '1' and in4_req_n = '0' then
						n_okt_control_state <= in4;

					end if;
				end if;

			when in1 =>
				out_data(BUFFER_BITS_WIDTH-1 downto BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH) <= std_logic_vector(to_unsigned(1, INPUT_BITS_WIDTH));
				out_data(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0)             	<= in1_data;
				out_req_n                                            					<= in1_req_n;
				in1_ack_n                                         						<= out_ack;
				
				if(input_select = std_logic_vector(to_unsigned(0,input_select'length))) then
					n_okt_control_state <= idle;

				elsif (in1_req_n = '1' and out_ack = '1') then
					if input_select(2) = '1' and in2_req_n = '0' then
						n_okt_control_state <= in2;

					elsif input_select(3) = '1' and in3_req_n = '0' then
						n_okt_control_state <= in3;

					elsif input_select(4) = '1' and in4_req_n = '0' then
						n_okt_control_state <= in4;

					elsif input_select(0) = '1' and in0_req_n = '0' then
						n_okt_control_state <= in0;

					end if;
				end if;

			when in2 =>
				out_data(BUFFER_BITS_WIDTH-1 downto BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH) <= std_logic_vector(to_unsigned(2, INPUT_BITS_WIDTH));
				out_data(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0)             	<= in2_data;
				out_req_n                                            					<= in2_req_n;
				in2_ack_n                                           					<= out_ack;
				
				if(input_select = std_logic_vector(to_unsigned(0,input_select'length))) then
					n_okt_control_state <= idle;

				elsif (in2_req_n = '1' and out_ack = '1') then
					if input_select(3) = '1' and in3_req_n = '0' then
						n_okt_control_state <= in3;

					elsif input_select(4) = '1' and in4_req_n = '0' then
						n_okt_control_state <= in4;

					elsif input_select(0) = '1' and in0_req_n = '0' then
						n_okt_control_state <= in0;

					elsif input_select(1) = '1' and in1_req_n = '0' then
						n_okt_control_state <= in1;

					end if;
				end if;

			when in3 =>
				out_data(BUFFER_BITS_WIDTH-1 downto BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH) <= std_logic_vector(to_unsigned(3, INPUT_BITS_WIDTH));
				out_data(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0)             	<= in3_data;
				out_req_n                                            					<= in3_req_n;
				in3_ack_n                                         						<= out_ack;
				
				if(input_select = std_logic_vector(to_unsigned(0,input_select'length))) then
					n_okt_control_state <= idle;

				elsif (in3_req_n = '1' and out_ack = '1') then
					if input_select(4) = '1' and in4_req_n = '0' then
						n_okt_control_state <= in4;

					elsif input_select(0) = '1' and in0_req_n = '0' then
						n_okt_control_state <= in0;

					elsif input_select(1) = '1' and in1_req_n = '0' then
						n_okt_control_state <= in1;

					elsif input_select(2) = '1' and in2_req_n = '0' then
						n_okt_control_state <= in2;

					end if;
				end if;

			when in4 =>
				out_data(BUFFER_BITS_WIDTH-1 downto BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH) <= std_logic_vector(to_unsigned(4, INPUT_BITS_WIDTH));
				out_data(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0)             	<= in4_data;
				out_req_n                                            					<= in4_req_n;
				in4_ack_n                                      							<= out_ack;
				
				if(input_select = std_logic_vector(to_unsigned(0,input_select'length))) then
					n_okt_control_state <= idle;

				elsif (in4_req_n = '1' and out_ack = '1') then
					if input_select(0) = '1' and in0_req_n = '0' then
						n_okt_control_state <= in0;

					elsif input_select(1) = '1' and in1_req_n = '0' then
						n_okt_control_state <= in1;

					elsif input_select(2) = '1' and in2_req_n = '0' then
						n_okt_control_state <= in2;

					elsif input_select(3) = '1' and in3_req_n = '0' then
						n_okt_control_state <= in3;

					end if;
				end if;

		end case;
	end process;

end RTL;

