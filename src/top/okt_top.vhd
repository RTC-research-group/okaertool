
library IEEE;
use IEEE.std_logic_1164.ALL;
use work.okt_global_pkg.all;
use work.okt_top_pkg.all;
use work.okt_imu_pkg.all;

entity okt_top is
	port(
		--        sys_clkp     : in    std_logic; -- The clock is generated in CU module
		--        sys_clkn     : in    std_logic;
		rst          : in    std_logic;
		-- USB 3.0 interface
		okUH         : in    std_logic_vector(OK_UH_WIDTH_BUS - 1 downto 0);
		okHU         : out   std_logic_vector(OK_HU_WIDTH_BUS - 1 downto 0);
		okUHU        : inout std_logic_vector(OK_UHU_WIDTH_BUS - 1 downto 0);
		okAA         : inout std_logic;
		-- AER INPUT interfaces
		rome_a_data  	  : in    std_logic_vector(ROME_DATA_BITS_WIDTH - 1 downto 0);
		rome_a_req_n 	  : in    std_logic;
		rome_a_ack_n 	  : out   std_logic;
		rome_b_data  	  : in    std_logic_vector(ROME_DATA_BITS_WIDTH - 1 downto 0);
		rome_b_req_n 	  : in    std_logic;
		rome_b_ack_n 	  : out   std_logic;
		node_data    	  : in    std_logic_vector(NODE_DATA_BITS_WIDTH - 1 downto 0);
		node_req_n   	  : in    std_logic;
		node_out_ack_n   : out   std_logic;
		-- AER OUTPUT interface
		out_data     : out   std_logic_vector(NODE_IN_DATA_BITS_WIDTH - 1 downto 0);
		out_req_n    : out   std_logic;
		node_in_ack_n    : in    std_logic;
		-- Status leds
		leds         : out   std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0)
	);
end okt_top;

architecture Behavioral of okt_top is
	--sys signals
	signal okClk : std_logic;
	signal rst_n : std_logic;
	signal rst_sw : std_logic;
	
	--latch signals
	signal rome_a_req_latch_0 : std_logic;
	signal rome_a_req_latch_1 : std_logic;
	signal rome_b_req_latch_0 : std_logic;
	signal rome_b_req_latch_1 : std_logic;
	signal node_req_latch_0   : std_logic;
	signal node_req_latch_1   : std_logic;

	--cu signals
	signal in_ecu_data  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal in_ecu_rd    : std_logic;
	signal in_ecu_ready : std_logic;
	signal out_osu_data  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal out_osu_wr    : std_logic;
	signal out_osu_ready : std_logic;	
	signal input_sel : std_logic_vector(NUM_INPUTS - 1 downto 0);
	
	--imu signals
	signal imu_req_n    : std_logic;
	signal imu_aer_data : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal imu_ack_n    : std_logic;

	--status signals
	signal status_cu 	: std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
	signal status_ecu	: std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
	signal status_osu	: std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
	
	signal cmd : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	
	--osu signals
	signal osu_ack: std_logic;
	signal osu_imu_ack_n: std_logic;
	signal ecu_osu_ack_n : std_logic;
	

begin

	-- 0 = led on; 1 = led off 
	leds  <= not (status_ecu(2 downto 0) & "000" & status_cu(1 downto 0));
	rst_n <= not (rst or rst_sw);

	-- Sync input signals
	syncronizer : process(okClk, rst_n)
	begin
		if (rst_n = '0') then
			rome_a_req_latch_0 <= '1';
			rome_a_req_latch_1 <= '1';
			rome_b_req_latch_0 <= '1';
			rome_b_req_latch_1 <= '1';
			node_req_latch_0   <= '1';
			node_req_latch_1   <= '1';

		elsif rising_edge(okClk) then
			rome_a_req_latch_0 <= rome_a_req_n;
			rome_a_req_latch_1 <= rome_a_req_latch_0;
			rome_b_req_latch_0 <= rome_b_req_n;
			rome_b_req_latch_1 <= rome_b_req_latch_0;
			node_req_latch_0   <= node_req_n;
			node_req_latch_1   <= node_req_latch_0;

		end if;
	end process;

--	-- TODO Output is not used yet.
--	out_data  <= (others => '0');
--	out_req_n <= '1';
	-------------------------------------

	cu_inst : entity work.okt_cu
		port map(
		--SYS
			clk       => okClk,
			rst_n     => rst_n,
			rst_sw    => rst_sw,
		--USB
			okUH      => okUH,
			okHU      => okHU,
			okUHU     => okUHU,
			okAA      => okAA,
		--ECU
			ecu_data  => in_ecu_data,
			ecu_rd    => in_ecu_rd,
			ecu_ready => in_ecu_ready,
		--OSU
			osu_data  => out_osu_data,
			osu_wr    => out_osu_wr,
			osu_ready => out_osu_ready,
		--INTERFACE
			input_sel => input_sel,
			status    => status_cu,
			cmd => cmd
		);

	imu_inst : entity work.okt_imu
		port map(
			clk          => okClk,
			rst_n        => rst_n,
			in0_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto rome_a_data'length => '0') & rome_a_data,
			in0_req_n    => rome_a_req_latch_1,
			in0_ack_n    => rome_a_ack_n,
			in1_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto rome_b_data'length => '0') & rome_b_data,
			in1_req_n    => rome_b_req_latch_1,
			in1_ack_n    => rome_b_ack_n,
			in2_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto node_data'length => '0') & node_data,
			in2_req_n    => node_req_latch_1,
			in2_ack_n    => node_out_ack_n,
			input_select => input_sel,
			out_data     => imu_aer_data,
			out_req_n    => imu_req_n,
			ecu_node_in_ack_n => osu_imu_ack_n
		);

	ecu_inst : entity work.okt_ecu
		port map(
			clk       => okClk,
			rst_n     => rst_n,
			ecu_req_n     => imu_req_n,
			aer_data  => imu_aer_data,
			ecu_out_ack_n     => ecu_osu_ack_n,
			out_data  => in_ecu_data,
			out_rd    => in_ecu_rd,
			out_ready => in_ecu_ready,
			status    => status_ecu,
			cmd       => cmd 	--Add process depending on cmd PASS or MON
		);
		
	osu_inst : entity work.okt_osu
		port map(
			clk           => okClk,
			rst_n      	  => rst_n,
			aer_in_data   => imu_aer_data,
			req_in_data_n => imu_req_n,
			ecu_in_ack_n     => ecu_osu_ack_n,
			cmd           => cmd,
			in_data  => out_osu_data,
			in_wr    => out_osu_wr,
			in_ready => out_osu_ready,
			node_in_data  => out_data,
			node_req_n    => out_req_n,
			node_in_osu_ack_n    => node_in_ack_n,
			ecu_node_out_ack_n    	  => osu_imu_ack_n
		);
		
end Behavioral;
