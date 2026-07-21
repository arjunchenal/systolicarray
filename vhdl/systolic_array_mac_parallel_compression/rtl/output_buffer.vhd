-- ==============================================================================================================================================
--  File Name   : output_buffer.vhd
--  Author      : Arjun Chenal
--  Created On  : 26-12-2025
--  Description : output buffer to align multi row parallel data for row dependent clock cycle delay. Each row i is delayed by (ROWS - 1 - i).
-- ==============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Output_Buffer is
    generic (
        ROWS       : positive := 4;
        DATA_WIDTH : positive := 32
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        data_in  : in  std_logic_vector(ROWS*DATA_WIDTH-1 downto 0); 
        data_out : out std_logic_vector(ROWS*DATA_WIDTH-1 downto 0) 
    );
end entity;

architecture rtl of Output_Buffer is
    subtype word_t is std_logic_vector(DATA_WIDTH-1 downto 0);
    type row_array_t is array (0 to ROWS-1) of word_t;

    signal in_array  : row_array_t;
    signal out_array : row_array_t;

begin

    process(data_in)
    begin
        for i in 0 to ROWS-1 loop
            in_array(i) <= data_in((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH);
        end loop;
    end process;

    gen_rows: for i in 0 to ROWS-1 generate
        constant NUM_DELAYS : integer := (ROWS - 1) - i;
    begin
        
        gen_direct: if NUM_DELAYS = 0 generate
            out_array(i) <= in_array(i);
        end generate;

        gen_delay: if NUM_DELAYS > 0 generate
            type delay_chain_t is array (0 to NUM_DELAYS-1) of word_t;
            signal shift_regs : delay_chain_t;
        begin
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        shift_regs <= (others => (others => '0'));
                    else
                        shift_regs(0) <= in_array(i);
                        for k in 1 to NUM_DELAYS-1 loop
                            shift_regs(k) <= shift_regs(k-1);
                        end loop;
                    end if;
                end if;
            end process;
            out_array(i) <= shift_regs(NUM_DELAYS-1);
        end generate;

    end generate;

    process(out_array)
    begin
        for i in 0 to ROWS-1 loop
            data_out((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= out_array(i);
        end loop;
    end process;

end architecture;