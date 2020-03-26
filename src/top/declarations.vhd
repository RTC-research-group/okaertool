--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package declarations is

	attribute box_type : string;

	type cmdMonitorType is (Nothing, Monitoring);
	
	type cmdLoggerType is (Nothing, Log, Stop_Log, Download_Log);
	
	type cmdPlayerType is (Nothing, Load_Data, Start_Player, Stop_Player);
	
	type multiplexorType is (Nothing, Monitor_EN, Logger_EN, Player_EN);
	
	type selInputType is (Nothing, A, B);
		
	component AER_BUS_Multiplexer port
		(
			selIN : in selInputType;
				
			AER_A_DATA : in  STD_LOGIC_VECTOR (15 downto 0);
			REQ_A : in  STD_LOGIC;
			ACK_A : out  STD_LOGIC;
		  
			AER_B_DATA : in  STD_LOGIC_VECTOR (15 downto 0);
			REQ_B : in  STD_LOGIC;
			ACK_B : out  STD_LOGIC;
		  
			AER_OUT_DATA : out  STD_LOGIC_VECTOR (15 downto 0);
			REQ_OUT : out  STD_LOGIC;
			ACK_OUT : in  STD_LOGIC
		);
	end component;
	
	
	component Fifo_wr32_2048_rd16_4096 port
		(
			RST: IN STD_LOGIC;
			WR_CLK: IN STD_LOGIC;
			RD_CLK: IN STD_LOGIC;
			DIN: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			WR_EN: IN STD_LOGIC;
			RD_EN: IN STD_LOGIC;
			DOUT: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			FULL: OUT STD_LOGIC;
			EMPTY: OUT STD_LOGIC
--			RD_DATA_COUNT: OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
--			WR_DATA_COUNT: OUT STD_LOGIC_VECTOR(10 DOWNTO 0)
		);
	end component;
	attribute box_type of fifo_wr32_2048_rd16_4096 : component is "black_box";
	
	
	component fifo_wr32_rd32_1024 port
		(
			RST : IN STD_LOGIC;
			CLK: IN STD_LOGIC;
			DIN : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			WR_EN : IN STD_LOGIC;
			RD_EN : IN STD_LOGIC;
			DOUT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			FULL : OUT STD_LOGIC;
			EMPTY : OUT STD_LOGIC
		);
	end component;
	attribute box_type of fifo_wr32_rd32_1024 : component is "black_box";
	
	
	component fifo_wr16_4096_rd32_2048 port
		(
			RST: IN STD_LOGIC;
			WR_CLK: IN STD_LOGIC;
			RD_CLK: IN STD_LOGIC;
			DIN: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			WR_EN: IN STD_LOGIC;
			RD_EN: IN STD_LOGIC;
			DOUT: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			FULL: OUT STD_LOGIC;
			EMPTY: OUT STD_LOGIC
		);
	end component;
	attribute box_type of fifo_wr16_4096_rd32_2048 : component is "black_box";
	
	component fifo_wr32_2048_rd32_2048 port
		(
			RST: IN STD_LOGIC;
			WR_CLK: IN STD_LOGIC;
			RD_CLK: IN STD_LOGIC;
			DIN: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			WR_EN: IN STD_LOGIC;
			RD_EN: IN STD_LOGIC;
			DOUT: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			FULL: OUT STD_LOGIC;
			EMPTY: OUT STD_LOGIC
		);
	end component;
	attribute box_type of fifo_wr32_2048_rd32_2048 : component is "black_box";
	
	
	component AER_OUT_Handshaker port
		( 
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;

			DATA_VALID : in  STD_LOGIC;
			READ_DATA : out  STD_LOGIC;
			AER_TIME_ADDR : in  STD_LOGIC_VECTOR (31 downto 0);
			
			REQ : out  STD_LOGIC;
			AER_DATA : out  STD_LOGIC_VECTOR (15 downto 0);
			ACK : in  STD_LOGIC
		);
	end component;
	
	
	component scale_clock port
		(
			CLK_100MHZ : IN  STD_LOGIC;
			RST : IN  STD_LOGIC;
			CLK_1MHZ : OUT STD_LOGIC
		);
	end component;

	component usb_read_filter port
		(
			CLK : IN  STD_LOGIC;
			RST : IN STD_LOGIC;
			INPUT : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
			FILTER : IN  STD_LOGIC;
			OUTPUT : OUT  STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component;
	
	component AER_Merger port
		(
			CLK : in STD_LOGIC;
			RST : in STD_LOGIC;
			LED : out  STD_LOGIC_VECTOR (7 downto 0);
			
			AER_ROME : in  STD_LOGIC_VECTOR (15 downto 0);
			REQ_ROME : in  STD_LOGIC;
			ACK_ROME : out  STD_LOGIC;
			
			AER_PAER_A : in  STD_LOGIC_VECTOR (15 downto 0);
			REQ_PAER_A : in  STD_LOGIC;
			ACK_PAER_A : out  STD_LOGIC;
			
			AER_OUT : out  STD_LOGIC_VECTOR (15 downto 0);
			REQ_OUT : out  STD_LOGIC;
			ACK_OUT : in  STD_LOGIC
		);
	end component;
	
	
	component Monitor port
		(
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;
			CMD : in cmdMonitorType;
			REQ : in  STD_LOGIC;
			AER_DATA : in  STD_LOGIC_VECTOR (15 downto 0);
			ACK : out  STD_LOGIC;
			OB_DATA : out  STD_LOGIC_VECTOR (31 downto 0);
			OB_WRITE : out  STD_LOGIC;
			OB_FULL : in STD_LOGIC;
			LED : out STD_LOGIC_VECTOR(3 downto 0)
		);
	end component;
	
	
	component Logger port
		(	
			CLK : in  STD_LOGIC;
			RST : in  STD_LOGIC;
						
			AER_DATA : in  STD_LOGIC_VECTOR (15 downto 0);
			REQ : in  STD_LOGIC;
			ACK : out  STD_LOGIC;
						
			LED : out STD_LOGIC_VECTOR (2 downto 0);--(5 downto 0);
			CMD : cmdLoggerType;
			
			OB_WRITE : out  STD_LOGIC;
			OB_DATA : out  STD_LOGIC_VECTOR (31 downto 0);
			OB_FULL : in STD_LOGIC;
			RST_OB : out STD_LOGIC;
			
			P0_CMD_EN : out  STD_LOGIC;
			P0_CMD_INSTR : out  STD_LOGIC_VECTOR (2 downto 0);
			P0_CMD_BL : out  STD_LOGIC_VECTOR (5 downto 0);
			P0_CMD_BYTE_ADDR : out  STD_LOGIC_VECTOR (29 downto 0);
			P0_CMD_FULL : in STD_LOGIC;
			P0_CMD_EMPTY : in STD_LOGIC;

			P0_RD_DATA : in  STD_LOGIC_VECTOR (31 downto 0);
			P0_RD_EMPTY : in  STD_LOGIC;
			P0_RD_FULL : in  STD_LOGIC;
			P0_RD_EN : out  STD_LOGIC;
			
			P0_WR_EN : out  STD_LOGIC;
			P0_WR_DATA : out  STD_LOGIC_VECTOR (31 downto 0);
			P0_WR_MASK : out  STD_LOGIC_VECTOR (3 downto 0);
			P0_WR_FULL : in STD_LOGIC;
			P0_WR_EMPTY : in STD_LOGIC
		);
	end component;
	
	
	component player_m port
		(
			CLK : in STD_LOGIC;
			RST : in STD_LOGIC;
			LED : out STD_LOGIC_VECTOR (2 downto 0);

			CMD : cmdPlayerType;
			
			IB_EMPTY : in STD_LOGIC;
			IB_DATA : in STD_LOGIC_VECTOR (31 downto 0);
			IB_READ : out STD_LOGIC;
			RST_FIFO_IN : out STD_LOGIC;
			
			AER_OUT : out STD_LOGIC_VECTOR (15 downto 0);
			REQ_OUT : out STD_LOGIC;
			ACK_OUT : in STD_LOGIC;
			
			P0_CMD_EN : out STD_LOGIC;
			P0_CMD_INSTR : out  STD_LOGIC_VECTOR (2 downto 0);
			P0_CMD_BL : out  STD_LOGIC_VECTOR (5 downto 0);
			P0_CMD_BYTE_ADDR : out  STD_LOGIC_VECTOR (29 downto 0);
			P0_CMD_FULL : in STD_LOGIC;
			P0_CMD_EMPTY : in STD_LOGIC;
			
			P0_WR_EN : out  STD_LOGIC;
			P0_WR_DATA : out  STD_LOGIC_VECTOR (31 downto 0);
			P0_WR_MASK : out  STD_LOGIC_VECTOR (3 downto 0);
			--P0_WR_COUNT : in STD_LOGIC_VECTOR(6 downto 0);
			P0_WR_FULL : in STD_LOGIC;
			P0_WR_EMPTY : in STD_LOGIC;
			
			P0_RD_DATA : in  STD_LOGIC_VECTOR (31 downto 0);
			P0_RD_EMPTY : in  STD_LOGIC;
			P0_RD_FULL : in  STD_LOGIC;
			P0_RD_EN : out  STD_LOGIC
			--P0_RD_COUNT : in STD_LOGIC_VECTOR(6 downto 0)
		);
	end component;
	
	
	-- DDR controller
	component DDR2 generic 
		(
			C3_P0_MASK_SIZE : integer := 4;
			C3_P0_DATA_PORT_SIZE : integer := 32;
			C3_P1_MASK_SIZE : integer := 4;
			C3_P1_DATA_PORT_SIZE : integer := 32;
			DEBUG_EN : integer := 0;
			C3_MEMCLK_PERIOD : integer := 3200;
			C3_CALIB_SOFT_IP : string := "TRUE";
			C3_SIMULATION : string := "FALSE";
			C3_RST_ACT_LOW : integer := 0;
			C3_INPUT_CLK_TYPE : string := "DIFFERENTIAL";
			C3_MEM_ADDR_ORDER : string := "ROW_BANK_COLUMN";
			C3_NUM_DQ_PINS : integer := 16;
			C3_MEM_ADDR_WIDTH : integer := 13;
			C3_MEM_BANKADDR_WIDTH : integer := 3
		);
		port 
		(
			mcb3_dram_dq : inout STD_LOGIC_VECTOR(C3_NUM_DQ_PINS-1 downto 0);
			mcb3_dram_a : out STD_LOGIC_VECTOR(C3_MEM_ADDR_WIDTH-1 downto 0);
			mcb3_dram_ba : out STD_LOGIC_VECTOR(C3_MEM_BANKADDR_WIDTH-1 downto 0);
			mcb3_dram_ras_n : out STD_LOGIC;
			mcb3_dram_cas_n : out STD_LOGIC;
			mcb3_dram_we_n : out STD_LOGIC;
			mcb3_dram_odt : out STD_LOGIC;
			mcb3_dram_cke : out STD_LOGIC;
			mcb3_dram_dm : out STD_LOGIC;
			mcb3_dram_udqs : inout STD_LOGIC;
			mcb3_dram_udqs_n : inout STD_LOGIC;
			mcb3_rzq : inout STD_LOGIC;
			mcb3_zio : inout STD_LOGIC;
			mcb3_dram_udm : out STD_LOGIC;
			
			c3_sys_clk_p : in STD_LOGIC;
			c3_sys_clk_n : in STD_LOGIC;
			c3_sys_rst_i : in STD_LOGIC;
			c3_calib_done : out STD_LOGIC;
			c3_clk0 : out STD_LOGIC;
			c3_rst0 : out STD_LOGIC;
			
			mcb3_dram_dqs : inout STD_LOGIC;
			mcb3_dram_dqs_n : inout STD_LOGIC;
			mcb3_dram_ck : out STD_LOGIC;
			mcb3_dram_ck_n : out STD_LOGIC;
			
			c3_p0_cmd_clk : in STD_LOGIC;
			c3_p0_cmd_en : in STD_LOGIC;
			c3_p0_cmd_instr : in STD_LOGIC_VECTOR(2 downto 0);
			c3_p0_cmd_bl : in STD_LOGIC_VECTOR(5 downto 0);
			c3_p0_cmd_byte_addr : in STD_LOGIC_VECTOR(29 downto 0);
			c3_p0_cmd_empty : out STD_LOGIC;
			c3_p0_cmd_full : out STD_LOGIC;
			
			c3_p0_wr_clk : in STD_LOGIC;
			c3_p0_wr_en : in STD_LOGIC;
			c3_p0_wr_mask : in STD_LOGIC_VECTOR(C3_P0_MASK_SIZE-1 downto 0);
			c3_p0_wr_data : in STD_LOGIC_VECTOR(C3_P0_DATA_PORT_SIZE-1 downto 0);
			c3_p0_wr_full : out STD_LOGIC;
			c3_p0_wr_empty : out STD_LOGIC;
			c3_p0_wr_count : out STD_LOGIC_VECTOR(6 downto 0);
			c3_p0_wr_underrun : out STD_LOGIC;
			c3_p0_wr_error : out STD_LOGIC;
			
			c3_p0_rd_clk : in STD_LOGIC;
			c3_p0_rd_en : in STD_LOGIC;
			c3_p0_rd_data : out STD_LOGIC_VECTOR(C3_P0_DATA_PORT_SIZE-1 downto 0);
			c3_p0_rd_full : out STD_LOGIC;
			c3_p0_rd_empty : out STD_LOGIC;
			c3_p0_rd_count : out STD_LOGIC_VECTOR(6 downto 0);
			c3_p0_rd_overflow : out STD_LOGIC;
			c3_p0_rd_error	: out STD_LOGIC
		);
	end component;
	
	component SPIgen port
		(
			clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			SCLK : out  STD_LOGIC;
			MOSI : out  STD_LOGIC;
			ready : out STD_LOGIC;
			data : in  STD_LOGIC_VECTOR (7 downto 0);
			enTX : in  STD_LOGIC
		);
	end component;
	
end declarations;
