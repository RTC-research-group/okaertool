
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.okt_global_pkg.all;
use work.okt_cu_pkg.all;
use work.okt_imu_pkg.all;
use work.okt_top_pkg.all;
use work.okt_fifo_pkg.all;
use work.FRONTPANEL.all;

entity okt_cu is                        -- Control Unit
	Port(
		clk       : out   std_logic;    -- 100.8 MHz
		rst_n     : in    std_logic;
		
		-- USB 3.0 interface
		okUH      : in    std_logic_vector(OK_UH_WIDTH_BUS - 1 downto 0);
		okHU      : out   std_logic_vector(OK_HU_WIDTH_BUS - 1 downto 0);
		okUHU     : inout std_logic_vector(OK_UHU_WIDTH_BUS - 1 downto 0);
		okAA      : inout std_logic;
		
		-- ECU interface
		ecu_data  : in    std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		ecu_rd    : out   std_logic;
		ecu_ready : in    std_logic;
		
		--OSU interface
		--osu_data  : out   std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		--osu_wr    : out   std_logic;
		--osu_ready : in    std_logic;
		
		-- Input selection
		--input_sel : out   std_logic_vector(NUM_INPUTS - 1 downto 0);
		
--		-- DAC signals
		DAC_RST:          out   std_logic;
		DAC_CLR:          out   std_logic;
		nDAC_CS:          out   std_logic;
		DAC_SDI:          out   std_logic;
		DAC_SCLK:         out   std_logic;
		
		--IPOT signals
		IPOT_QDATA:       in    std_logic;
		IPOT_LATCH:       out   std_logic;
		IPOT_SDATA:       out   std_logic;
		IPOT_SCLK:        out   std_logic;
		IPOT_RST:        out   std_logic;

		-- Leds
		status    : out   std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
		
		--cmd output
		cmd	 	 :	out	std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
		
		--fovea output 
		fovea_selx:       out std_logic_vector(8 downto 0);
		fovea_sely:       out std_logic_vector(8 downto 0);
		fovea_allx:       out std_logic;
		fovea_ally:       out std_logic;
		fovea_T:          out std_logic;
		fovea_R:          out std_logic;
		fovea_COMM:       out std_logic;
		fovea_every4x:    out std_logic;
		fovea_every4y:    out std_logic;
		fovea_E_Y_COMM:   out std_logic;
		fovea_E_Y_TR:     out std_logic;
		fovea_E_FINAL_X:  out std_logic;
		
		
		--software reset output
		rst_sw        : out   std_logic;    -- sw rst coming from the USB trigger end-point
		reset_cores   : out std_logic_vector(3 downto 0)
	);
end okt_cu;

architecture Behavioral of okt_cu is

--	constant Mask_MON    :    std_logic_vector(2 downto 0):="001";
--	constant Mask_PASS   :    std_logic_vector(2 downto 0):="010";
--	constant Mask_SEQ    :    std_logic_vector(2 downto 0):="100";

	signal n_command   : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);

	-- ECU Signals
	signal n_ecu_data  : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal n_ecu_rd    : std_logic;
	signal n_ecu_ready : std_logic;
	

	-- USB signals
	signal okClk : std_logic;
	signal okHE  : std_logic_vector(OK_HE_WIDTH_BUS - 1 downto 0);
	signal okEH  : std_logic_vector(OK_EH_WIDTH_BUS - 1 downto 0);
	signal okEHx : std_logic_vector(OK_EH_WIDTH_BUS * OK_NUM_okEHx_END_POINTS - 1 downto 0);

-- OK Endpoints
	signal ep00wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --COMMAND
	signal ep01wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --BIT SETTING
	signal ep02wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --RESET

-- DAC ENDPOINTS	
	signal DAC0102            : std_logic_vector(2*BUFFER_BITS_WIDTH -1 downto 0):= (others => '0'); --DAC	
	signal DAC0102_prev       : std_logic_vector(2*BUFFER_BITS_WIDTH -1 downto 0):= (others => '0'); --DAC
	
	signal DAC01wire          : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --DAC
	signal DAC02wire          : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --DAC

--IPOT ENDPOINTS
	signal IPOTINwire         : std_logic_vector(102 - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOTINwire_prev    : std_logic_vector(102 - 1 downto 0):= (others => '0'); --IPOTS
	
	signal IPOT01wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT02wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT03wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT04wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT05wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT06wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS

    signal IPOT20wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT21wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT22wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT23wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT24wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS
	signal IPOT25wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0):= (others => '0'); --IPOTS

-- FIFO SIGNALS
	signal CU_fifo_w_data 		  : std_logic_vector(2*BUFFER_BITS_WIDTH - 1 downto 0);
	signal CU_fifo_w_en   		  : std_logic:='0';
	signal CU_fifo_r_data 		  : std_logic_vector(2*BUFFER_BITS_WIDTH - 1 downto 0);
	signal CU_fifo_r_en   		  : std_logic;
	signal CU_fifo_empty  		  : std_logic;
	signal CU_fifo_full  		  : std_logic;
	signal CU_fifo_almost_full   : std_logic;
	signal CU_fifo_almost_empty   : std_logic;
	signal CU_fifo_fill_count 	: integer range 64 - 1 downto 0;
	signal CU_fifo_w_en_latch      : std_logic:='0';
	
-- BTPipeIN
	signal epA0_datain      : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal epA0_read        : std_logic;
	signal epA0_blockstrobe : std_logic; -- @suppress "signal epA0_blockstrobe is never read"
	signal epA0_ready       : std_logic;
	

--  --DAC signals
    signal n_DAC_RST: std_logic := '0';
    signal n_DAC_CS_BUFFER: std_logic_vector(0 downto 0);
    signal n_DAC_CLR: std_logic:= '0';
    signal SPI_CPOL: std_logic := '0';
    signal SPI_CPHA: std_logic := '1';
    signal SPI_ENABLE: std_logic:= '0';
    signal SPI_CONT: std_logic := '0';
    signal SPI_TXDATA: std_logic_vector(47 downto 0);--ANCHURA 48
    signal SPI_RXDATA: std_logic_vector(47 downto 0);
    signal SPI_MISO: std_logic;
    signal SPI_MOSI: std_logic;
    signal SPI_BUSY: std_logic;
    --signal spi_latch: std_logic;
    signal SPI_ADDRESS : integer := 0;
    signal SPI_CLKDIV : integer := 400;  --divides (clk/2)/4
    signal SPI_CLK : std_logic;


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

--  --IPOT signals
    signal Ipot_datain: std_logic_vector(101 downto 0);
    signal Ipot_dataout:std_logic_vector(101 downto 0);
    signal Ipot_nCS:    std_logic;
    signal Ipot_SDO:    std_logic;
    signal Ipot_Q:      std_logic;
    signal Ipot_command:std_logic;
    signal Ipot_clk     :std_logic;
    signal Ipot_reset     :std_logic;
    --signal ipot_busy     :std_logic;
    
    
    signal status_n : std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);
    type state is (idle, busy_fall_0, busy_fall_1, wait_busy_rise);
    type state2 is (idle, write1, write2);
    type state3 is (idle, start, waitstop, stop);
	signal r_okt_cu_control_state, n_okt_cu_control_state : state;
	signal r_okt_fifo_control_state, n_okt_fifo_control_state : state2;
	signal r_okt_ipot_control_state, n_okt_ipot_control_state : state3;
	
	-- DEBUG
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of r_okt_cu_control_state, n_okt_cu_control_state, r_okt_fifo_control_state, n_okt_fifo_control_state, n_okt_ipot_control_state, r_okt_ipot_control_state: signal is "TRUE";
    attribute MARK_DEBUG of CU_fifo_empty: signal is "TRUE";
begin
	
	n_ecu_data  <= ecu_data;
	ecu_rd      <= n_ecu_rd;
	n_ecu_ready <= ecu_ready;
	
	status <= status_n;
	
	--ep00wire input
	cmd <= n_command;
	
	--FOVEA OUTPUT
	fovea_selx <= selx;
	fovea_sely <= sely;
	fovea_allx <= ALLX;
	fovea_ally <= ALLY;
	fovea_COMM <= COMM;
	fovea_R <= R;
	fovea_T <= T;
	fovea_every4x <= EVERY4X;
	fovea_every4y <= EVERY4Y;
	fovea_E_FINAL_X <= E_FINAL_X;
	fovea_E_Y_COMM <= E_Y_COMM;
	fovea_E_Y_TR <= E_Y_TR;
	
	--DAC OUTPUTS
	DAC_RST <= not n_DAC_RST;
	DAC_CLR <= not n_DAC_CLR;
    nDAC_CS <= n_DAC_CS_BUFFER(0);
    DAC_SDI <= SPI_MOSI;
    DAC_SCLK <= SPI_CLK;
    
    --IPOTS
    IPOT_LATCH  <= Ipot_nCS;
    IPOT_SDATA  <= Ipot_SDO;
    Ipot_Q      <= IPOT_QDATA;
    IPOT_SCLK   <= Ipot_clk;
    IPOT_RST    <= Ipot_reset;
-------------------------------------------------------------
-- OKHOST MODULE
-------------------------------------------------------------
	okHI : work.FRONTPANEL.okHost
		port map(
			okUH  => okUH,
			okHU  => okHU,
			okUHU => okUHU,
			okAA  => okAA,
			okClk => okClk,             -- 100.8 MHz
			okHE  => okHE,
			okEH  => okEH
		);
	clk <= okClk;


	okOR : work.FRONTPANEL.okWireOR
		generic map(
			N => OK_NUM_okEHx_END_POINTS
		)
		port map(
			okEH  => okEH,
			okEHx => okEHx
		);

---------------------------------------------------------------
---- COMMANDS
---------------------------------------------------------------	
	cmd_EP : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"00",
			ep_dataout => ep00wire
		);
---------------------------------------------------------------
---- FOVEATION
---------------------------------------------------------------		
	bit_setting : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"01",
			ep_dataout => ep01wire
		);
---------------------------------------------------------------
---- RESET
---------------------------------------------------------------		
	rst_EP : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"02",
			ep_dataout => ep02wire
		);
	n_DAC_CLR          <= ep02wire(7);
	n_DAC_RST          <= ep02wire(6);	
	Ipot_reset         <= ep02wire(5);
	reset_cores        <= ep02wire(4 downto 1);
	rst_sw             <= ep02wire(0);
	status_n(0)        <= ep02wire(0);

---------------------------------------------------------------
---- DACs
---------------------------------------------------------------			
	DAC_operation_1 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"03",
			ep_dataout => DAC01wire
		);
	DAC_operation_2 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"04",
			ep_dataout => DAC02wire
		);

        DAC0102(31 downto 0) <= DAC01wire;
        DAC0102(63 downto 32) <= DAC02wire;

---------------------------------------------------------------
---- IPOTs
---------------------------------------------------------------			
	IPOT_operation_1 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"05",
			ep_dataout => IPOT01wire
		);
	IPOT_operation_2 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"06",
			ep_dataout => IPOT02wire
		);
	IPOT_operation_3 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"07",
			ep_dataout => IPOT03wire
		);
	IPOT_operation_4 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"08",
			ep_dataout => IPOT04wire
		);
	IPOT_operation_5 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"09",
			ep_dataout => IPOT05wire
		);
	IPOT_operation_6 : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"0A",
			ep_dataout => IPOT06wire
		);	

    IPOTINwire(1*IPOT_BITS_WIDTH - 1 downto 0*IPOT_BITS_WIDTH) <= IPOT01wire(16 downto 0);
    IPOTINwire(2*IPOT_BITS_WIDTH - 1 downto 1*IPOT_BITS_WIDTH) <= IPOT02wire(16 downto 0);
    IPOTINwire(3*IPOT_BITS_WIDTH - 1 downto 2*IPOT_BITS_WIDTH) <= IPOT03wire(16 downto 0);
    IPOTINwire(4*IPOT_BITS_WIDTH - 1 downto 3*IPOT_BITS_WIDTH) <= IPOT04wire(16 downto 0);                                   
    IPOTINwire(5*IPOT_BITS_WIDTH - 1 downto 4*IPOT_BITS_WIDTH) <= IPOT05wire(16 downto 0);
    IPOTINwire(6*IPOT_BITS_WIDTH - 1 downto 5*IPOT_BITS_WIDTH) <= IPOT06wire(16 downto 0);
    
	IPOT_operation_7 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(7 * OK_EH_WIDTH_BUS - 1 downto 6 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"20",
	       ep_datain   => IPOT20wire
	    );
	IPOT_operation_8 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(6 * OK_EH_WIDTH_BUS - 1 downto 5 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"21",
	       ep_datain   => IPOT21wire
	    );
	IPOT_operation_9 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(5 * OK_EH_WIDTH_BUS - 1 downto 4 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"22",
	       ep_datain   => IPOT22wire
	    );
	IPOT_operation_10 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(4 * OK_EH_WIDTH_BUS - 1 downto 3 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"23",
	       ep_datain   => IPOT23wire
	    );
	IPOT_operation_11 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(3 * OK_EH_WIDTH_BUS - 1 downto 2 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"24",
	       ep_datain   => IPOT24wire
	    );
	IPOT_operation_12 : work.FRONTPANEL.okWireOut
	   port map(
	       okHE        => okHE,
	       okEH        => okEHx(2 * OK_EH_WIDTH_BUS - 1 downto 1 * OK_EH_WIDTH_BUS),
	       ep_addr     => x"25",
	       ep_datain   => IPOT25wire
	    );
	       	
---------------------------------------------------------------
---- ECU OUTPUT
---------------------------------------------------------------	
	data_out_EP :work.FRONTPANEL. okBTPipeOut
		port map(
			okHE           => okHE,
			okEH           => okEHx(1 * OK_EH_WIDTH_BUS - 1 downto 0 * OK_EH_WIDTH_BUS),
			ep_addr        => x"A0", 
			ep_read        => epA0_read,
			ep_blockstrobe => epA0_blockstrobe,
			ep_datain      => epA0_datain,
			ep_ready       => epA0_ready
		);

-------------------------------------------------------------
-- FIFO
-------------------------------------------------------------	
	ring_buffer : entity work.ring_buffer
		generic map(
			RAM_DEPTH => 64,
			RAM_WIDTH => 64
		)
		port map(
			clk    => okClk,
			rst  => rst_n,
			wr_data => CU_fifo_w_data,
			wr_en   => CU_fifo_w_en,
			rd_data => CU_fifo_r_data,
			rd_en   => CU_fifo_r_en,
			empty  => CU_fifo_empty,
			full   => CU_fifo_full,
			full_next => CU_fifo_almost_full,
			fill_count => CU_fifo_fill_count,
			empty_next => CU_fifo_almost_empty
		);
		
-------------------------------------------------------------
-- SPI MASTER
-------------------------------------------------------------
	SPI_MASTER :entity work.spi_master
		generic map(
			slaves => 1,
			d_width => 48 --OJITO LA AMPLITUD
		)
		port map(
			clock                => okClk,           --sys clock
			--IPOT                 => '0',
			reset_n              => rst_n,           --sys reset
			enable               => SPI_ENABLE, 
			cpol                 => SPI_CPOL,        --set to 0
			cpha                 => SPI_CPHA,        --set to 0
			cont                 => SPI_CONT,        --set to 0
			addr                 => SPI_ADDRESS,     --set to 0
			tx_data              => SPI_TXDATA,
			miso                 => SPI_MISO,        --not used
			ss_n                 => n_DAC_CS_BUFFER, --assigned to output
			mosi                 => SPI_MOSI,        --assigned to output
			--latch                => spi_latch,
			busy                 => SPI_BUSY,
			sclk                 => SPI_CLK,         --assigned to output
			rx_data              => SPI_RXDATA,      --not used	
			clk_div              => SPI_CLKDIV       --set to 4 (divides clk by 8 -> 12.5 MHz)
		);	

-------------------------------------------------------------
-- IPOTs
-------------------------------------------------------------
    IPOTs :entity work.IPOT_serialtransmitter 
    port map(
        Data_in         => Ipot_datain,
        Q               => Ipot_Q,
        clk             => okClk,
        rst_n           => rst_n,
        command         => Ipot_command, 
        Data_out        => Ipot_dataout,
        nCS             => Ipot_nCS,
        SDO             => Ipot_SDO,
        clkenable       => Ipot_clk
        );
        
        
        
--    IPOTs :entity work.spi_master   
--		generic map(
--			slaves => 1,
--			d_width => 102 --OJITO LA AMPLITUD
--		)
--		port map(
--			clock                => okClk,           --sys clock
--			IPOT                 => '1',
--			reset_n              => rst_n,           --sys reset
--			enable               => Ipot_command, 
--			cpol                 => '0',        --set to 0
--			cpha                 => '0',        --set to 0
--			cont                 => '0',        --set to 0
--			addr                 => SPI_ADDRESS,     --set to 0
--			tx_data              => Ipot_datain,
--			miso                 => Ipot_Q,        --not used
--			ss_n                 => n_DAC_CS_BUFFER, --assigned to output
--			mosi                 => Ipot_SDO,        --assigned to output
--			latch                => Ipot_nCS,
--			busy                 => ipot_busy,
--			sclk                 => Ipot_clk,         --assigned to output
--			rx_data              => Ipot_dataout,      --not used	
--			clk_div              => SPI_CLKDIV       --set to 4 (divides clk by 8 -> 12.5 MHz)
--		);	

-------------------------------------------------------------
-- SIGNALS UPDATE
-------------------------------------------------------------
    signals_updating: process (okClk, rst_n)
    begin
    if rst_n = '0' then
        r_okt_cu_control_state <= idle;
        r_okt_fifo_control_state <= idle;
        r_okt_ipot_control_state <= idle;
    elsif rising_edge(okClk) then
        r_okt_cu_control_state <= n_okt_cu_control_state;
        r_okt_fifo_control_state <= n_okt_fifo_control_state;
        r_okt_ipot_control_state <= n_okt_ipot_control_state;
    end if;
    end process;

-------------------------------------------------------------
-- FILLING THE FIFO
-------------------------------------------------------------
    Filling_fifo: process (rst_n
    , r_okt_fifo_control_state
    ,DAC0102
    )
    begin
        n_okt_fifo_control_state <= r_okt_fifo_control_state;
        CU_fifo_w_en <= '0';
        CU_fifo_w_data <= (others => '0');
        case r_okt_fifo_control_state is
            when idle =>
                if DAC0102 /= DAC0102_prev and n_command(1)='1' then --Mejorar escritura en la memoria
                    n_okt_fifo_control_state <= write1;
                end if;
                
            when write1 =>
                CU_fifo_w_data <= DAC0102;
                DAC0102_prev <= DAC0102;
                CU_fifo_w_en <= '1';
                n_okt_fifo_control_state <= write2;
            
            when write2 =>
                n_okt_fifo_control_state <= idle;

        end case;
    end process;

-------------------------------------------------------------
-- DAC_ENDPOINT
-------------------------------------------------------------
	DAC_endpoint : process(rst_n
	,SPI_BUSY
	,r_okt_cu_control_state
	,SPI_BUSY
	,CU_fifo_empty
	--,CU_fifo_r_data
	)
	begin
	n_okt_cu_control_state <= r_okt_cu_control_state;	
    CU_fifo_r_en <= '0';
    SPI_ENABLE <= '0';
    case r_okt_cu_control_state is
        when idle =>
            if CU_fifo_empty = '0' then
                n_okt_cu_control_state <= busy_fall_0;
            end if;
            
        when busy_fall_0 =>
            if SPI_BUSY = '0' then
                SPI_TXDATA(23 downto 0) <= CU_fifo_r_data(23 downto 0);
                SPI_TXDATA(47 downto 24) <= CU_fifo_r_data(55 downto 32); --QUITAR COMENTARIO
                SPI_ENABLE <= '1';
                CU_fifo_r_en <= '1';
                n_okt_cu_control_state <= busy_fall_1;
            else 
                SPI_TXDATA <= (others => '0');
            end if;
            
        when busy_fall_1 =>
            n_okt_cu_control_state <= wait_busy_rise;
            
        when wait_busy_rise => --Examinar si esto puede ser un problema
        if (SPI_BUSY = '0') then
            SPI_TXDATA(23 downto 0) <= (others => '0');
            SPI_TXDATA(47 downto 24) <= (others => '0'); --VOLVER A QUITAR COMENTARIO
            n_okt_cu_control_state <= idle;
        end if;
    end case;
		
	end process;

-------------------------------------------------------------
-- IPOT_ENDPOINT
-------------------------------------------------------------
	IPOT_endpoint : process(rst_n
	,Ipot_nCS
	,r_okt_ipot_control_state
	,IPOTINwire
	)
	begin
	n_okt_ipot_control_state <= r_okt_ipot_control_state;
	Ipot_command <= '0';
        case r_okt_ipot_control_state is
            when idle =>
                if n_command(2) = '1' and IPOTINwire /= IPOTINwire_prev then
                    n_okt_ipot_control_state <= start;
                end if;
                
            when start =>
                Ipot_datain<= IPOTINwire;
                IPOTINwire_prev <= IPOTINwire;
                Ipot_command <= '1';
                n_okt_ipot_control_state <= waitstop;
                
            when waitstop =>
            Ipot_command <= '1';
                if Ipot_nCS = '1' then --Examinar si esto puede ser un problema
                Ipot_command <= '0';
                    n_okt_ipot_control_state <= stop;
                end if;
                
            when stop =>
                IPOT20wire(16 downto 0) <= Ipot_dataout(6*IPOT_BITS_WIDTH - 1 downto 5*IPOT_BITS_WIDTH);
                IPOT21wire(16 downto 0) <= Ipot_dataout(5*IPOT_BITS_WIDTH - 1 downto 4*IPOT_BITS_WIDTH);
                IPOT22wire(16 downto 0) <= Ipot_dataout(4*IPOT_BITS_WIDTH - 1 downto 3*IPOT_BITS_WIDTH);
                IPOT23wire(16 downto 0) <= Ipot_dataout(3*IPOT_BITS_WIDTH - 1 downto 2*IPOT_BITS_WIDTH);
                IPOT24wire(16 downto 0) <= Ipot_dataout(2*IPOT_BITS_WIDTH - 1 downto 1*IPOT_BITS_WIDTH);
                IPOT25wire(16 downto 0) <= Ipot_dataout(1*IPOT_BITS_WIDTH - 1 downto 0*IPOT_BITS_WIDTH);
                n_okt_ipot_control_state <= idle;
                
            --default: idle;
        end case;
		
	end process;
	
-------------------------------------------------------------
-- USB COMMANDS AND FOVEA
-------------------------------------------------------------
	USB_Commands: process(rst_n
	, ep00wire
	, ep01wire
	)
	begin
		if (rst_n = '0') then
        -- wirein ep00
            n_command   <= (others => '0');
        -- wirein ep01 
            selx      <= (others => '0');
            sely      <= (others => '0');
            EVERY4X   <= '0'; EVERY4Y   <= '0';
            ALLX      <= '0'; ALLY      <= '0';
            R         <= '0'; T         <= '0';
            COMM      <= '0'; E_Y_COMM  <= '0';
            E_Y_TR    <= '0'; E_FINAL_X <= '0';
        
		else
		-- wirein ep00
		    n_command(COMMAND_BIT_WIDTH - 1 downto 0)  <= ep00wire(COMMAND_BIT_WIDTH - 1 downto 0);
		-- wirein ep01
            selx      <= ep01wire(8 downto 0);
            sely      <= ep01wire(17 downto 9);
            EVERY4X   <= ep01wire(18);
            EVERY4Y   <= ep01wire(19);
            ALLX      <= ep01wire(20);
            ALLY      <= ep01wire(21);
            R         <= ep01wire(22);
            T         <= ep01wire(23);
            COMM      <= ep01wire(24);
            E_Y_COMM  <= ep01wire(25);
            E_Y_TR    <= ep01wire(26);
            E_FINAL_X <= ep01wire(27);
            
		end if;
	end process;	
		  
-------------------------------------------------------------
-- STATUS MULTIPLEXER
-------------------------------------------------------------
	command_multiplexer : process(
	n_command
	,epA0_read, n_ecu_data, n_ecu_ready --ECU signals
                                  )
	begin
		
		n_ecu_rd    <= epA0_read;
		epA0_datain <= n_ecu_data;
		epA0_ready  <= n_ecu_ready;
		
		status_n(LEDS_BITS_WIDTH - 1 downto 1) <= (others => '0');

		if (n_command(0) = '1') then -- MON command. Send out captured event to USB
			status_n(1) <= '1';     -- Set MON led
		end if;
		if (n_command(1) = '1') then -- DAC_CONFIGURE command. Enables DAC configuration
			status_n(2) <= '1';     -- Set DAC led
		end if;
		
	end process;

end Behavioral;

