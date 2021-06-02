
library ieee;
use ieee.std_logic_1164.all;
use work.okt_global_pkg.all;
use work.okt_cu_pkg.all;
use work.okt_imu_pkg.all;
use work.okt_top_pkg.all;
use work.FRONTPANEL.all;

entity okt_cu is                        -- Control Unit
	Port(
		clk       : out   std_logic;    -- 100.8 MHz
		rst_n     : in    std_logic;
		rst_sw    : out   std_logic;    -- sw rst coming from the USB trigger end-point
		-- USB 3.0 interface
		okUH      : in    std_logic_vector(OK_UH_WIDTH_BUS - 1 downto 0);
		okHU      : out   std_logic_vector(OK_HU_WIDTH_BUS - 1 downto 0);
		okUHU     : inout std_logic_vector(OK_UHU_WIDTH_BUS - 1 downto 0);
		okAA      : inout std_logic;
		-- ECU interface
		ecu_data  : in    std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
		ecu_rd    : out   std_logic;
		ecu_ready : in    std_logic;
		-- Input selection
		input_sel : out   std_logic_vector(NUM_INPUTS - 1 downto 0);
		-- Leds
		status    : out   std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0)
	);
end okt_cu;

architecture Behavioral of okt_cu is

	signal n_command   : std_logic_vector(COMMAND_BIT_WIDTH - 1 downto 0);
	signal n_input_sel : std_logic_vector(NUM_INPUTS - 1 downto 0);

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
	signal ep00wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal ep01wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal ep02wire         : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal epA0_datain      : std_logic_vector(BUFFER_BITS_WIDTH - 1 downto 0);
	signal epA0_read        : std_logic;
	signal epA0_blockstrobe : std_logic; -- @suppress "signal epA0_blockstrobe is never read"
	signal epA0_ready       : std_logic;

	signal status_n : std_logic_vector(LEDS_BITS_WIDTH - 1 downto 0);

begin

	n_ecu_data  <= ecu_data;
	ecu_rd      <= n_ecu_rd;
	n_ecu_ready <= ecu_ready;

	status <= status_n;

	input_sel <= n_input_sel;

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

	-- WireIn to receive command from USB
	cmd_EP : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"00",
			ep_dataout => ep00wire
		);

	-- WireIn to receive IMU input_sel from USB
	selInput_EP : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"01",
			ep_dataout => ep01wire
		);

	-- WireIn to receive sw rst from USB
	rst_EP : work.FRONTPANEL.okWireIn
		port map(
			okHE       => okHE,
			ep_addr    => x"02",
			ep_dataout => ep02wire
		);
	rst_sw      <= ep02wire(0);
	status_n(0) <= ep02wire(0);

	-- PipeOut to send data out using the USB
	data_out_EP : work.FRONTPANEL.okBTPipeOut
		port map(
			okHE           => okHE,
			okEH           => okEHx(1 * OK_EH_WIDTH_BUS - 1 downto 0 * OK_EH_WIDTH_BUS),
			ep_addr        => x"A0",
			ep_read        => epA0_read,
			ep_blockstrobe => epA0_blockstrobe,
			ep_datain      => epA0_datain,
			ep_ready       => epA0_ready
		);

	-- Reset command and input_sel signals
	process(rst_n, ep00wire, ep01wire)
	begin
		if (rst_n = '0') then
			n_command   <= (others => '0');
			n_input_sel <= (others => '0');
		else
			n_command   <= ep00wire(COMMAND_BIT_WIDTH - 1 downto 0);
			n_input_sel <= ep01wire(NUM_INPUTS - 1 downto 0);
		end if;
	end process;

	-- Multiplexer that select the data path depending of the command
	command_multiplexer : process(n_command, epA0_read, n_ecu_data, n_ecu_ready)
	begin
		n_ecu_rd                               <= '0';
		epA0_datain                            <= (others => '0');
		epA0_ready                             <= '0';
		status_n(LEDS_BITS_WIDTH - 1 downto 1) <= (others => '0');

		case n_command is
			when "01" =>                -- ECU command. Send out captured event to USB
				n_ecu_rd    <= epA0_read;
				epA0_datain <= n_ecu_data;
				epA0_ready  <= n_ecu_ready;
				status_n(1) <= '1';     -- Set ECU led

			when others =>
				null;
		end case;
	end process;

end Behavioral;

