library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity InputRegisterArray is
    generic (
        COLS       : positive := 8;
        DATA_WIDTH : positive := 8;
        group_size : positive := 2
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        clear_pipeline : in  std_logic;
        en             : in  std_logic;
        data_in_row    : in  std_logic_vector((COLS*group_size*DATA_WIDTH-1) downto 0);
        data_to_cols   : out std_logic_vector((COLS*group_size)-1 downto 0)
    );
end entity;

architecture rtl of InputRegisterArray is
    constant total_stream : integer := COLS*group_size;
    type delay_array is array (0 to total_stream-1) of std_logic_vector(COLS-1 downto 0);
    
    signal delay_reg      : delay_array;
    signal next_delay     : delay_array;
    signal bit_count_reg  : integer range 0 to DATA_WIDTH-1;
    signal next_bit_count : integer range 0 to DATA_WIDTH-1;
    signal data_row_buffer      : std_logic_vector((COLS*group_size*DATA_WIDTH-1) downto 0);
    signal next_data_row_buffer : std_logic_vector((COLS*group_size*DATA_WIDTH-1) downto 0);

begin

    -- Sequential Logic
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or clear_pipeline = '1' then
                bit_count_reg   <= 0;
                data_row_buffer <= (others => '0');
                for i in 0 to total_stream-1 loop
                    delay_reg(i) <= (others => '0');
                end loop;
            else
                bit_count_reg   <= next_bit_count;
                delay_reg       <= next_delay;
                data_row_buffer <= next_data_row_buffer;
            end if;
        end if;
    end process;

    -- Combinational Logic
    process(bit_count_reg, delay_reg, data_in_row, data_row_buffer, en)
        variable serial_bits : std_logic_vector(total_stream-1 downto 0);
        variable v : integer;
        variable physical_column : integer;
    begin
        next_bit_count       <= bit_count_reg;
        next_delay           <= delay_reg;
        next_data_row_buffer <= data_row_buffer;

        if en = '1' and bit_count_reg = 0 then
            next_data_row_buffer <= data_in_row;
        end if;

        for i in 0 to total_stream-1 loop
            v := i * DATA_WIDTH;
            if bit_count_reg = 0 then
                serial_bits(i) := data_in_row(v + bit_count_reg);
            else
                serial_bits(i) := data_row_buffer(v + bit_count_reg);
            end if;
        end loop;

        for i in 0 to total_stream-1 loop
            physical_column := i / group_size;
            if physical_column = 0 then
                data_to_cols(i) <= serial_bits(i);
            else
                data_to_cols(i) <= delay_reg(i)(physical_column-1);
            end if;
        end loop;

        if en = '1' then
            if bit_count_reg = DATA_WIDTH-1 then
                next_bit_count <= 0;
            else
                next_bit_count <= bit_count_reg + 1;
            end if; 

            for i in group_size to total_stream-1 loop
                next_delay(i) <= delay_reg(i)(COLS-2 downto 0) & serial_bits(i); 
            end loop;
        else 
            next_bit_count <= 0; 
        end if;
    end process;
    
end architecture;