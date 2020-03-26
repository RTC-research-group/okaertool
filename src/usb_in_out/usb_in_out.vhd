----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:21:18 05/12/2019 
-- Design Name: 
-- Module Name:    usb_in_out - Behavioral 
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
use IEEE.STD_LOGIC_1164.ALL;
use work.global_pkg.ALL;
use work.usb_in_out_pkg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity usb_in_out is
	Port ( 
		CLK 			: in  STD_LOGIC;
		CLK_USB		: in  STD_LOGIC;
		RST 			: in  STD_LOGIC;
		
		OB_DATA 		: in  STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
		OB_VALID 	: in  STD_LOGIC;
		OB_ENABLE	: out STD_LOGIC;
		OB_STATUS 	: out  STD_LOGIC;
		
		IB_DATA 		: out  STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
		IB_VALID 	: out  STD_LOGIC;
		IB_ENABLE	: in  STD_LOGIC;
		IB_STATUS 	: out  STD_LOGIC;
		
		okHE			: in STD_LOGIC_VECTOR (okHE_BUS_WIDTH-1 downto 0);
		okEH_OB		: out STD_LOGIC_VECTOR (okEH_BUS_WIDTH-1 downto 0);
		okEH_IB		: out STD_LOGIC_VECTOR (okEH_BUS_WIDTH-1 downto 0)
			);
end usb_in_out;

architecture Behavioral of usb_in_out is

	signal pipe_out_data		:	STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
	signal pipe_out_read		:	STD_LOGIC;
	signal pipe_out_ready	:	STD_LOGIC;
	
	signal pipe_in_data		:	STD_LOGIC_VECTOR (BUFFER_WIDTH-1 downto 0);
	signal pipe_in_write		:	STD_LOGIC;
	signal pipe_in_ready		:	STD_LOGIC;
	
	signal ob_fifo_full		:	STD_LOGIC;
	signal ob_fifo_empty		:	STD_LOGIC;
	
	signal ib_fifo_full		:	STD_LOGIC;
	signal ib_fifo_empty		:	STD_LOGIC;
	
begin

	pipe_out_ready <= not ob_fifo_empty;
	OB_ENABLE		<= not ob_fifo_full;
	OB_STATUS		<= pipe_out_read;
	
	OB_FIFO : fifo port map (
		RST 		=> RST,
		WR_CLK 	=> CLK,
		RD_CLK 	=> CLK_USB,
		DIN 		=> OB_DATA,
		WR_EN 	=> OB_VALID,
		RD_EN 	=> pipe_out_read,
		DOUT 		=> pipe_out_data,
		FULL 		=> ob_fifo_full,
		EMPTY 	=> ob_fifo_empty
	);

	OB : okBTPipeOut port map (
		okHE				=>okHE, 
		okEH				=>okEH_OB,  
		ep_addr			=>ok_OB_ADDRESS, 
      ep_read			=>pipe_out_read, 
		ep_blockstrobe	=>open, 
		ep_datain		=>pipe_out_data, 
		ep_ready			=>pipe_out_ready
	);
	
	
	
	pipe_in_ready 	<= IB_ENABLE and (not ib_fifo_full);
	IB_STATUS		<= pipe_in_write;
		
	IB_FIFO : fifo port map (
		RST 		=> RST,
		WR_CLK 	=> CLK_USB,
		RD_CLK 	=> CLK,
		DIN		=> OB_DATA,
		WR_EN 	=> OB_VALID,
		RD_EN 	=> pipe_out_read,
		DOUT 		=> pipe_out_data,
		FULL 		=> ib_fifo_full,
		EMPTY 	=> ib_fifo_empty
	);

	IB : okBTPipeIn port map (
		okHE				=>okHE, 
		okEH				=>okEH_IB,  
		ep_addr			=>ok_IB_ADDRESS, 
      ep_write			=>pipe_in_write, 
		ep_blockstrobe	=>open, 
		ep_dataout		=>pipe_in_data, 
		ep_ready			=>pipe_in_ready
	);

end Behavioral;

