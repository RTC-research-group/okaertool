-- TestBench Template 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.okt_imu_pkg.ALL;
use work.global_pkg.ALL;

ENTITY okt_imu_tb IS
END okt_imu_tb;

ARCHITECTURE behavior OF okt_imu_tb IS 

	signal clk : std_logic;
	signal rst : std_logic;

	signal rome_a_data : std_logic_vector(ROME_DATA_BITS_WIDTH-1 downto 0);
	signal rome_a_req  : std_logic;
	signal rome_a_ack  : std_logic;

	signal rome_b_data : std_logic_vector(ROME_DATA_BITS_WIDTH-1 downto 0);
	signal rome_b_req  : std_logic;
	signal rome_b_ack  : std_logic;

	signal node_data : std_logic_vector(NODE_DATA_BITS_WIDTH-1 downto 0);
	signal node_req  : std_logic;
	signal node_ack  : std_logic;

	signal logger_data : std_logic_vector(BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-1 downto 0);
	signal logger_req  : std_logic;
	signal logger_ack  : std_logic;

	signal spinnaker_data : std_logic_vector(SPINNAKER_BITS_DATA_WIDTH-1 downto 0);
	signal spinnaker_req  : std_logic;
	signal spinnaker_ack  : std_logic;

	signal input_select : std_logic_vector(NUM_INPUTS-1 downto 0);

	signal out_data : std_logic_vector(BUFFER_BITS_WIDTH-1 downto 0);
	signal out_req  : std_logic;
	signal out_ack  : std_logic;

	signal status : STD_LOGIC;
	
	-- Clock period definitions
   constant CLK_period : time := 20 ns;
	
	type state is (idle, req_fall, req_rise);
	signal current_state_rome_a, next_state_rome_a 			: state;
	signal current_state_rome_b, next_state_rome_b 			: state;
	signal current_state_node, next_state_node 				: state;
	signal current_state_logger, next_state_logger			: state;
	signal current_state_spinnaker, next_state_spinnaker 	: state;
	
	type state_handshake is (idle, req_fall);
	signal current_state_out, next_state_out 	: state_handshake;
          
BEGIN

	-- Component Instantiation
	okt_imu : entity work.okt_imu
		PORT MAP(
			clk          => clk,
			rst_n        => rst,
			in0_data     => std_logic_vector(to_unsigned(0,BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-ROME_DATA_BITS_WIDTH)) & rome_a_data,
			in0_req_n    => rome_a_req,
			in0_ack_n    => rome_a_ack,
			in1_data     => std_logic_vector(to_unsigned(0,BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-ROME_DATA_BITS_WIDTH)) & rome_b_data,
			in1_req_n    => rome_b_req,
			in1_ack_n    => rome_b_ack,
			in2_data     => std_logic_vector(to_unsigned(0,BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-NODE_DATA_BITS_WIDTH)) & node_data,
			in2_req_n    => node_req,
			in2_ack_n    => node_ack,
			in3_data     => std_logic_vector(to_unsigned(0,BUFFER_BITS_WIDTH-INPUT_BITS_WIDTH-SPINNAKER_BITS_DATA_WIDTH)) & spinnaker_data,
			in3_req_n    => spinnaker_req,
			in3_ack_n    => spinnaker_ack,
			in4_data     => logger_data,
			in4_req_n    => logger_req,
			in4_ack_n    => logger_ack,
			input_select => input_select,
			out_data     => out_data,
			out_req_n    => out_req,
			out_ack      => out_ack,
			status       => status
		);

	-- Clock process definitions
	CLK_process :process
	begin
		clk <= '0';
		wait for CLK_period/2;
		clk <= '1';
		wait for CLK_period/2;
	end process;

   -- Stimulus process
   stim_proc: process
   begin
   		rst <= '0';
      	input_select <= b"00000";
      	wait for CLK_period*5;
     	 rst <= '1';
		
		-- insert stimulus here
      	wait for CLK_period;
	  	input_select <= b"00001";
	  	wait for CLK_period*20;
	  	input_select <= b"00000";
	  	wait for CLK_period*20;
	  	input_select <= b"00011";
	  	wait for CLK_period*20;
	  	input_select <= b"00100";
	  	wait for CLK_period*20;
	  	input_select <= b"01000";
		wait for CLK_period*20;
		input_select <= b"10000";
		wait for CLK_period*20;
		input_select <= b"11111";
     	wait;
   end process;
	
	signals_update : process (clk, rst)
	begin
		if rst = '0' then
			current_state_rome_a 	<= idle;
			current_state_rome_b 	<= idle;
			current_state_node 		<= idle;
			current_state_logger	<= idle;
			current_state_spinnaker <= idle;
			current_state_out		<= idle;
			
		elsif rising_edge(clk) then
			current_state_rome_a 	<= next_state_rome_a;
			current_state_rome_b 	<= next_state_rome_b;
			current_state_node 		<= next_state_node;
			current_state_logger	<= next_state_logger;
			current_state_spinnaker <= next_state_spinnaker;
			current_state_out		<= next_state_out;

		end if;
	end process;
	
	FSM_transition : process (current_state_rome_a, rome_a_ack, 
								current_state_rome_b, rome_b_ack,
								current_state_node, node_ack, 
								current_state_logger, logger_ack,
								current_state_spinnaker, spinnaker_ack)
	begin
		next_state_rome_a 		<= current_state_rome_a;
		next_state_rome_b 		<= current_state_rome_b;
		next_state_node	 		<= current_state_node;
		next_state_logger	 	<= current_state_logger;
		next_state_spinnaker	<= current_state_spinnaker;
		
		rome_a_req				<= '1';
		rome_b_req				<= '1';
		node_req				<= '1';
		logger_req				<= '1';
		spinnaker_req			<= '1';
		
		rome_a_data			 	<= (others=>'0');
		rome_b_data			 	<= (others=>'0');
		node_data			 	<= (others=>'0');
		logger_data			 	<= (others=>'0');
		spinnaker_data		 	<= (others=>'0');
		
		case current_state_rome_a is
			when idle =>
				if rome_a_ack = '1' then
					next_state_rome_a <= req_fall;
				end if;
				
			when req_fall =>
				rome_a_req 			<= '0';
				rome_a_data			<= std_logic_vector(to_unsigned(1, rome_a_data'length));
				if rome_a_ack = '0' then
					next_state_rome_a 	<= req_rise;
				end if;
			
			when req_rise =>
				rome_a_req 			<= '1';
				next_state_rome_a <= idle;
				
		end case;
		
		
		case current_state_rome_b is
			when idle =>
				if rome_b_ack = '1' then
					next_state_rome_b <= req_fall;
				end if;
				
			when req_fall =>
				rome_b_req 			<= '0';
				rome_b_data			<= std_logic_vector(to_unsigned(2, rome_b_data'length));
				if rome_b_ack = '0' then
					next_state_rome_b 	<= req_rise;
				end if;
			
			when req_rise =>
				rome_b_req 			<= '1';
				next_state_rome_b <= idle;
					
		end case;
		
		
		case current_state_node is
			when idle =>
				if node_ack = '1' then
					next_state_node <= req_fall;
				end if;
				
			when req_fall =>
				node_req 			<= '0';
				node_data			<= std_logic_vector(to_unsigned(3, node_data'length));
				if node_ack = '0' then
					next_state_node 	<= req_rise;
				end if;
			
			when req_rise =>
				node_req 			<= '1';
				next_state_node <= idle;
					
		end case;
		
		case current_state_logger is
			when idle =>
				if logger_ack = '1' then
					next_state_logger <= req_fall;
				end if;
				
			when req_fall =>
				logger_req 			<= '0';
				logger_data			<= std_logic_vector(to_unsigned(5, logger_data'length));
				if logger_ack = '0' then
					next_state_logger 	<= req_rise;
				end if;
			
			when req_rise =>
				logger_req 			<= '1';
				next_state_logger <= idle;
					
		end case;
		
		case current_state_spinnaker is
			when idle =>
				if spinnaker_ack = '1' then
					next_state_spinnaker <= req_fall;
				end if;
				
			when req_fall =>
				spinnaker_req 			<= '0';
				spinnaker_data			<= std_logic_vector(to_unsigned(4, spinnaker_data'length));
				if spinnaker_ack = '0' then
					next_state_spinnaker 	<= req_rise;
				end if;
			
			when req_rise =>
				spinnaker_req 			<= '1';
				next_state_spinnaker <= idle;
					
		end case;
	end process;
	
	
	OUT_FSM_transitions : process (current_state_out, out_req)
	begin
		next_state_out	<= current_state_out;
		out_ack			<= '1';
		
		case current_state_out is
			when idle =>
				if out_req = '0' then
					next_state_out <= req_fall;
				end if;
				
			when req_fall =>
				out_ack	<= '0';
				if out_req = '1' then
					next_state_out <= idle;				
				end if;
				
		end case;
	end process;

  END;
