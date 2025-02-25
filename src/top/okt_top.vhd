
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
		--rome_a_ack_n_S 	  : in   std_logic;
		rome_b_data  	  : in    std_logic_vector(ROME_DATA_BITS_WIDTH - 1 downto 0);
		rome_b_req_n 	  : in    std_logic;
		rome_b_ack_n 	  : out   std_logic;
		--rome_b_ack_n_S 	  : in   std_logic;
		rome_c_data  	  : in    std_logic_vector(ROME_DATA_BITS_WIDTH - 1 downto 0);
		rome_c_req_n 	  : in    std_logic;
		rome_c_ack_n 	  : out   std_logic;
		--rome_c_ack_n_S 	  : in   std_logic;
		rome_d_data  	  : in    std_logic_vector(ROME_DATA_BITS_WIDTH - 1 downto 0);
		rome_d_req_n 	  : in    std_logic;
		rome_d_ack_n 	  : out   std_logic;
		--rome_d_ack_n_S 	  : in   std_logic;
		
		--fovea output  
		cu_selx:       out std_logic_vector(8 downto 0);
		cu_sely:       out std_logic_vector(8 downto 0);
		cu_allx:       out std_logic;
		cu_ally:       out std_logic;
		cu_T:          out std_logic;
		cu_R:          out std_logic;
		cu_COMM:       out std_logic;
		cu_every4x:    out std_logic;
		cu_every4y:    out std_logic;
		cu_E_Y_COMM:   out std_logic;
		cu_E_Y_TR:     out std_logic;
		cu_E_FINAL_X:  out std_logic;
		
		--DAC Output
		T_DAC_RST:          out   std_logic;
		T_DAC_CLR:          out   std_logic;
		T_nDAC_CS:          out   std_logic;
		T_DAC_SDI:          out   std_logic;
		T_DAC_SCLK:         out   std_logic;	
		
		T_IPOT_QDATA:       in    std_logic;
		T_IPOT_LATCH:       out   std_logic;
		T_IPOT_SDATA:       out   std_logic;
		T_IPOT_SCLK:        out   std_logic;	
		T_IPOT_RST:         out   std_logic;

        --reset cores 
        rst_cores : out std_logic_vector(3 downto 0);
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
	signal rome_c_req_latch_0 : std_logic;
	signal rome_c_req_latch_1 : std_logic;
	signal rome_d_req_latch_0 : std_logic;
	signal rome_d_req_latch_1 : std_logic;


	--cu signals
	signal in_ecu_data  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal in_ecu_rd    : std_logic;
	signal in_ecu_ready : std_logic;
	
	signal core_reset : std_logic_vector (3 downto 0);

	--signal input_sel : std_logic_vector(NUM_INPUTS - 1 downto 0);
	
	--imu signals
	signal imu_req_n    : std_logic;
	signal imu_aer_data : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal imu_in0 : std_logic_vector(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto 0);
	signal imu_in1 : std_logic_vector(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto 0);
	signal imu_in2 : std_logic_vector(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto 0);
	signal imu_in3 : std_logic_vector(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto 0);
	signal imu_ack_n    : std_logic;
	
--	signal rome_a_ack_n_Sg : std_logic;
--	signal rome_b_ack_n_Sg : std_logic;
--	signal rome_c_ack_n_Sg : std_logic;
--	signal rome_d_ack_n_Sg : std_logic;
	
--	signal rome_a_ack_n_Sr : std_logic;
--	signal rome_b_ack_n_Sr : std_logic;
--	signal rome_c_ack_n_Sr : std_logic;
--	signal rome_d_ack_n_Sr : std_logic;

	--status signals
	signal status_cu 	: std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
	signal status_ecu	: std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
	signal cmd : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	
	--osu signals
	--signal osu_ack: std_logic;
	signal osu_imu_ack_n: std_logic;
	--signal ecu_osu_ack_n : std_logic;
	
	--  --Bit Fovea
    signal selx:        std_logic_vector(8 downto 0);
    signal sely:        std_logic_vector(8 downto 0);
    signal E_Y_COMM:    std_logic;
    signal E_Y_TR:      std_logic;
    signal R:           std_logic;
    signal T:           std_logic;
    signal COMM:        std_logic;
    signal ALLX:        std_logic;
    signal ALLY:        std_logic;
    signal E_FINAL_X:   std_logic;
    signal EVERY4X:     std_logic;
    signal EVERY4Y:     std_logic;
    
    --DAC
    signal n_DAC_RST: std_logic;
    signal n_DAC_CS: std_logic;
    signal n_DAC_CLR: std_logic;
    signal DAC_SDI: std_logic;
    signal DAC_CLK: std_logic;
    
    signal S_IPOT_QDATA: std_logic;
    signal S_IPOT_LATCH: std_logic;
    signal S_IPOT_SDATA: std_logic;
    signal S_IPOT_SCLK: std_logic;
    signal S_IPOT_RESET: std_logic;
	

begin

--PARA MIRAR EN LA PLACA _ ELIMINAR LUEGO
--    rome_a_ack_n_Sg <= rome_a_ack_n_S;
--    rome_b_ack_n_Sg <= rome_b_ack_n_S;
--    rome_c_ack_n_Sg <= rome_c_ack_n_S;
--    rome_d_ack_n_Sg <= rome_d_ack_n_S;

	-- 0 = led on; 1 = led off 
	leds  <= not (status_ecu(2 downto 0) & "000" & status_cu(1 downto 0));
	rst_n <= not (rst or rst_sw);
	rst_cores <= core_reset;
	
	--fovea input
	cu_selx <= selx;
	cu_sely <= sely;
	cu_allx <= ALLX;
	cu_ally <= ALLY;
	cu_COMM <= COMM;
	cu_R <= R;
	cu_T <= T;
	cu_every4x <= EVERY4X;
	cu_every4y <= EVERY4Y;
	cu_E_FINAL_X <= E_FINAL_X;
	cu_E_Y_COMM <= E_Y_COMM;
	cu_E_Y_TR <= E_Y_TR;
	
    --DAC
    T_DAC_RST <= n_DAC_RST;
    T_DAC_CLR <= n_DAC_CLR;
    T_DAC_SCLK <= DAC_CLK;
    T_DAC_SDI <= DAC_SDI;
    T_nDAC_CS <= n_DAC_CS;
    
    --IPOTS
    --T_IPOT_LATCH <= '0';
    
    T_IPOT_LATCH <= S_IPOT_LATCH;
    T_IPOT_SCLK <= S_IPOT_SCLK;
    T_IPOT_SDATA <= S_IPOT_SDATA;
    S_IPOT_QDATA <= T_IPOT_QDATA;
    T_IPOT_RST   <= S_IPOT_RESET;
    
    imu_in0(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH) <= (others => '0');
    imu_in0(ROME_DATA_BITS_WIDTH - 1 downto 0) <= rome_a_data;
    imu_in1(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH) <= (others => '0');
    imu_in1(ROME_DATA_BITS_WIDTH - 1 downto 0) <= rome_b_data;
    imu_in2(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH) <= (others => '0');
    imu_in2(ROME_DATA_BITS_WIDTH - 1 downto 0) <= rome_c_data;
    imu_in3(BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH) <= (others => '0');
    imu_in3(ROME_DATA_BITS_WIDTH - 1 downto 0) <= rome_d_data;

-------------------------------------------------------------
-- INPUT SYNCRONIZER
-------------------------------------------------------------
	syncronizer : process(okClk, rst_n)
	begin
		if (rst_n = '0') then
			rome_a_req_latch_0 <= '1';
			rome_a_req_latch_1 <= '1';
			rome_b_req_latch_0 <= '1';
			rome_b_req_latch_1 <= '1';
			rome_c_req_latch_0 <= '1';
			rome_c_req_latch_1 <= '1';
			rome_d_req_latch_0 <= '1';
			rome_d_req_latch_1 <= '1';


		elsif rising_edge(okClk) then
			rome_a_req_latch_0 <= rome_a_req_n;
			rome_a_req_latch_1 <= rome_a_req_latch_0;
			rome_b_req_latch_0 <= rome_b_req_n;
			rome_b_req_latch_1 <= rome_b_req_latch_0;
			rome_c_req_latch_0 <= rome_c_req_n;
			rome_c_req_latch_1 <= rome_c_req_latch_0;
			rome_d_req_latch_0 <= rome_d_req_n;
			rome_d_req_latch_1 <= rome_d_req_latch_0;

		end if;
	end process;

-------------------------------------------------------------
-- CONTROL UNIT
-------------------------------------------------------------
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
		--INTERFACE
			--input_sel => input_sel,
			status    => status_cu,
			reset_cores => core_reset,
			cmd => cmd,
		--FOVEA
			fovea_selx          => selx,
            fovea_sely          => sely,
            fovea_allx          => ALLX,
            fovea_ally          => ALLY,
            fovea_COMM          => COMM,
            fovea_R             => R,
            fovea_T             => T,
            fovea_every4x       => EVERY4X,
            fovea_every4y       => EVERY4Y,
            fovea_E_FINAL_X     => E_FINAL_X,
            fovea_E_Y_COMM      => E_Y_COMM,
            fovea_E_Y_TR        => E_Y_TR,
        --DAC
            DAC_RST             => n_DAC_RST,
            DAC_CLR             => n_DAC_CLR,
            nDAC_CS             => n_DAC_CS,
            DAC_SDI             => DAC_SDI,
            DAC_SCLK            => DAC_CLK,
		--IPOT
		    IPOT_QDATA       =>   S_IPOT_QDATA,
		    IPOT_LATCH       =>   S_IPOT_LATCH,
		    IPOT_SDATA       =>   S_IPOT_SDATA,
		    IPOT_RST         =>   S_IPOT_RESET,
		    IPOT_SCLK        =>   S_IPOT_SCLK
		);

-------------------------------------------------------------
-- INPUT MERGER
-------------------------------------------------------------

	imu_inst : entity work.okt_imu
		port map(
		--SYS
			clk          => okClk,
			rst_n        => rst_n,
		--IN0	
			--in0_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH => '0') & rome_a_data,
			in0_data     => imu_in0,
			in0_req_n    => rome_a_req_latch_1,
			in0_ack_n    => rome_a_ack_n, --ELIMINAR LA S
		--IN1
			--in1_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH => '0') & rome_b_data,
			in1_data     => imu_in1,
			in1_req_n    => rome_b_req_latch_1,
			in1_ack_n    => rome_b_ack_n, --ELIMINAR LA S
		--IN2
			--in2_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto ROME_DATA_BITS_WIDTH => '0') & rome_c_data,
			in2_data     => imu_in2,
			in2_req_n    => rome_c_req_latch_1,
			in2_ack_n    => rome_c_ack_n, --ELIMINAR LA S
		--IN3
			--in3_data     => (BUFFER_BITS_WIDTH - INPUT_BITS_WIDTH - 1 downto rome_d_data'length => '0') & rome_d_data,
			in3_data     => imu_in3,
			in3_req_n    => rome_d_req_latch_1,
			in3_ack_n    => rome_d_ack_n, --ELIMINAR LA S
			
			imu_command => cmd,
		--OUT
			out_data     => imu_aer_data,
			out_req_n    => imu_req_n,
			ecu_node_in_ack_n => osu_imu_ack_n
		);

-------------------------------------------------------------
-- EVENT CAPTURER
-------------------------------------------------------------
	ecu_inst : entity work.okt_ecu
		port map(
		--SYS
			clk                 => okClk,
			rst_n               => rst_n,
		--IN
			ecu_req_n           => imu_req_n,
			aer_data            => imu_aer_data,
			ecu_out_ack_n       => osu_imu_ack_n,
		--OUT
			out_data            => in_ecu_data,
			out_rd              => in_ecu_rd,
			out_ready           => in_ecu_ready,
		--CONTROL
			status              => status_ecu,
			cmd                 => cmd 	--Add process depending on cmd PASS or MON
		);
		
		
end Behavioral;
