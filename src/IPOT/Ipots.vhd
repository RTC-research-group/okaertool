library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IPOT_serialtransmitter is
    Port (
        Data_in : in  STD_LOGIC_VECTOR(101 downto 0);
        Q       : in  STD_LOGIC;
        clk     : in  STD_LOGIC;
        rst_n   : in  STD_LOGIC;
        command : in  STD_LOGIC; 
        Data_out: out STD_LOGIC_VECTOR(101 downto 0);
        nCS     : out STD_LOGIC;
        SDO     : out STD_LOGIC;
        clkenable     : out STD_LOGIC
        --OUTPUT reloj
        --OUTPUT RESET??
    );
end IPOT_serialtransmitter;




--architecture Behavioral of IPOT_serialtransmitter is

--    signal shift_reg : STD_LOGIC_VECTOR(101 downto 0) := (others => '0');
--    signal recv_reg  : STD_LOGIC_VECTOR(101 downto 0) := (others => '0');
--    signal bit_count : INTEGER range 0 to 102 := 0;
--    signal transmitting : STD_LOGIC := '0';
--    constant DIV_FACTOR : unsigned(31 downto 0) := to_unsigned(400, 32); --DIVISOR DE FRECUENCIA
--    signal counter     : unsigned(31 downto 0) := (others => '0');
--    signal enable_reg  : STD_LOGIC := '0';
--    --signal clk_enable  : std_logic;
    
--begin
----IPOT_Out_CLK <= enable_reg;
--    process(clk, rst_n)
--    begin
--        if rst_n = '0' then
--            counter    <= (others => '0');
--            enable_reg <= '0';
--        elsif rising_edge(clk) then
--            if counter = (DIV_FACTOR - 1) then
--                counter    <= (others => '0');
--                --enable_reg <= '1';
--                enable_reg <= not enable_reg;  -- Generate a single-cycle enable pulse
--            --elsif counter = to_unsigned(400, 32) then
--            else
--                counter    <= counter + 1;
--                --enable_reg <= '0';
--            --else counter    <= counter + 1;
--            end if;
--        end if;
--    end process;

--    --clk_enable <= enable_reg;
--    clkenable  <= enable_reg;
    
--    process (enable_reg, rst_n, Data_in)
--    begin
--        nCS <= '0';
--        if rst_n = '0' then
--            shift_reg <= (others => '0');
--            recv_reg <= (others => '0');
--            bit_count <= 0;
--            transmitting <= '0';
----            nCS <= '0';
--            SDO <= '0';
--            Data_out <= (others => '0');

--        elsif falling_edge(enable_reg) then
--            if transmitting = '0' then
--                if command = '1' then
--                    -- Start transmission when `command` is active
--                    shift_reg <= Data_in;
--                    recv_reg <= (others => '0');
--                    bit_count <= 0;
--                    transmitting <= '1';
----                    nCS <= '0';
--                end if;
--            else
--                -- Transmitting logic
--                SDO <= shift_reg(101); -- Send the MSB bit first
--                shift_reg <= shift_reg(100 downto 0) & '0'; -- Shift left
--                recv_reg <= recv_reg(100 downto 0) & Q; -- Shift in data from Q

--                bit_count <= bit_count + 1;

--                if bit_count = 102 then
--                    -- Transmission complete
--                    transmitting <= '0';
--                    nCS <= '1';
--                    Data_out <= recv_reg;
--                end if;
--            end if;
--        end if;
--    end process;

--end Behavioral;




architecture Behavioral of IPOT_serialtransmitter is
    constant N : integer := 400; -- Clock division factor
    type state_type is (idle, start_comm, transmit, end_comm, end_all);
    signal state       : state_type := idle;
    signal clk_counter : integer range 0 to N-1 := 0;
    signal bit_counter : integer range 0 to 102 := 0;
    signal shift_reg   : STD_LOGIC_VECTOR(101 downto 0) := (others => '0');
    signal recv_reg    : STD_LOGIC_VECTOR(101 downto 0) := (others => '0');
    signal clk_div     : STD_LOGIC := '1';

begin

    clkenable <= clk_div;
--    -- Clock Divider Process
--    process(clk, rst_n)
--    begin
--        if rst_n = '0' then
--            clk_counter  <= 0;
--            clk_div      <= '0';
--        elsif rising_edge(clk) then
--            if clk_counter = N-1 then
--                clk_counter <= 0;
--                clk_div     <= not clk_div;
--            else
--                clk_counter <= clk_counter + 1;
--            end if;            
--        end if;
--    end process;

--    -- Main State Machine
--    process(clk_div, rst_n)
--    begin
--        if rst_n = '0' then
--            state       <= idle;
--            SDO         <= '1';
--            --clkenable   <= '1';
--            nCS         <= '0';
--            bit_counter <= 0;
--            shift_reg   <= (others => '0');
--            recv_reg    <= (others => '0');
--            Data_out    <= (others => '0');
--        else 
--            if state = transmit then
--                clkenable <= clk_div;
--            else clkenable <= '1';
--            end if;
--            if falling_edge(clk_div) then
--            case state is
--                when idle =>
--                    SDO       <= '1';
--                    --clkenable <= '0';
--                    nCS       <= '0';
--                    if command = '1' then
--                        state       <= start_comm;
--                        shift_reg   <= Data_in;
--                        bit_counter <= 0;
--                    end if;
                
--                when start_comm =>
--                    SDO     <= '0';  -- Start condition
--                    nCS     <= '0';
--                    --clkenable <= '0';
--                    state   <= transmit;
                
--                when transmit =>
--                    if bit_counter < 102 then
--                        SDO        <= shift_reg(0);
--                        shift_reg  <= '0' & shift_reg(101 downto 1);
--                        recv_reg(bit_counter) <= Q;
--                        bit_counter <= bit_counter + 1;
--                    else
--                        state <= end_comm;
--                    end if;
                
--                when end_comm =>
--                    SDO       <= '1';
--                    --clkenable <= '0';
--                    nCS       <= '1';  -- Set nCS high for one cycle
--                    Data_out  <= recv_reg;
--                    state     <= idle;
--            end case;
----            else 
----                if state = transmit then
----                recv_reg(bit_counter) <= Q;
----                end if;
--            end if;
--        end if;
--    end process;
    
--end Behavioral;


    process(clk, rst_n)
    begin
        if rst_n = '0' then
            clk_counter  <= 0;
            clk_div      <= '1';
            state       <= idle;
            SDO         <= '1';
            nCS         <= '0';
            bit_counter <= 0;
            shift_reg   <= (others => '0');
            recv_reg    <= (others => '0');
            Data_out    <= (others => '0');
        elsif rising_edge(clk) then
        
            case state is
                when idle =>
                    SDO       <= '1';
                    clk_div   <= '1';
                    nCS       <= '0';
                    if command = '1' then
                        state       <= start_comm;
                        shift_reg   <= Data_in;
                        bit_counter <= 0;
                    end if;
                
                when start_comm =>
                    SDO     <= '0';  -- Start condition
                    nCS     <= '0';
                    state   <= transmit;
                
                when transmit =>
                    if clk_counter = N-1 then
                        clk_counter <= 0;
                        clk_div     <= not clk_div;
                        if clk_div = '1' and bit_counter < 102 then
                            --SDO        <= shift_reg(0);
                            --shift_reg  <= '0' & shift_reg(101 downto 1);
                            
                            SDO        <= shift_reg(101);
                            shift_reg  <= shift_reg(100 downto 0) & '0';
                            
                            recv_reg(bit_counter) <= Q;
                            bit_counter <= bit_counter + 1;
                        elsif bit_counter = 102 then
                            state <= end_comm;
                        end if;
                    else
                        clk_counter <= clk_counter + 1;
                    end if; 

                
                when end_comm =>
                    nCS       <= '0';  -- Set nCS high for one cycle
                    Data_out  <= recv_reg;
                    if clk_counter = N-1 then
                        clk_counter <= 0;
                        SDO <= '1';
                        nCS       <= '1';
                        state     <= end_all;
                    else
                        clk_counter <= clk_counter + 1;
                        state     <= end_comm;
                    end if; 

                when end_all =>
                    if clk_counter = N-1 then
                        clk_counter <= 0;
                        state     <= idle;
                    else
                        clk_counter <= clk_counter + 1;
                        state     <= end_all;
                    end if; 
            end case;       
        
                  
        end if;
    end process;
end Behavioral;