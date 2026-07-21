-- ==============================================================================================================
--  File Name   : input_register_array.vhd
--  Author      : Arjun Chenal
--  Created On  : 26-12-2025
--  Description : For diagonal input skew buffer for systolic array and each column i is delayed by i clock cycles.
-- ==============================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity InputRegisterArray is
    generic (
        COLS            : positive := 4;   -- number of columns
        DATA_WIDTH      : positive := 8;   -- bits per value
        group_size      : integer := 2;  -- number of inputs available for each PE to pick one
        OUT_WIDTH       : integer := 32
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        en  : in std_logic;
        data_in_row  : in  std_logic_vector(COLS*group_size*DATA_WIDTH-1 downto 0); -- Value to flipflop from controller or TB
        data_to_cols : out std_logic_vector(COLS*group_size*DATA_WIDTH-1 downto 0) -- From flipflop to Systolic PE
    );
end entity;


architecture rtl of InputRegisterArray is
    constant number_of_inputs : integer := COLS*group_size;
    subtype word_t is std_logic_vector(DATA_WIDTH-1 downto 0);
    type row_array_t is array (0 to number_of_inputs-1) of word_t;

    signal in_array  : row_array_t;
    signal out_array : row_array_t;

begin

    process(all)
    begin
        for i in 0 to number_of_inputs-1 loop
        in_array(i) <= data_in_row((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH);
        end loop;
    end process;


    gen_words: for i in 0 to number_of_inputs-1 generate
        constant COL_ID : integer := i / group_size;
    begin

        no_delay: if COL_ID = 0 generate
        signal reg0 : word_t := (others => '0');
        begin
        process(clk)
        begin
            if rising_edge(clk) then
            if rst = '1' then
                reg0 <= (others => '0');
            elsif en = '1' then
                reg0 <= in_array(i);
            end if;
            end if;
        end process;

        out_array(i) <= reg0;
        end generate;

        with_delay: if COL_ID > 0 generate
            type shift_t is array (0 to COL_ID) of word_t;
            signal sh : shift_t := (others => (others => '0'));
        begin
            process(clk)
            begin
                if rising_edge(clk) then
                if rst = '1' then
                    sh <= (others => (others => '0'));
                elsif en = '1' then
                    sh(0) <= in_array(i);
                    for k in 1 to COL_ID loop
                    sh(k) <= sh(k-1);
                    end loop;
                end if;
                end if;
            end process;

            out_array(i) <= sh(COL_ID);
        end generate;

    end generate;

    process(all)
    begin
        for i in 0 to number_of_inputs-1 loop
        data_to_cols((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= out_array(i);
        end loop;
    end process;

end architecture;