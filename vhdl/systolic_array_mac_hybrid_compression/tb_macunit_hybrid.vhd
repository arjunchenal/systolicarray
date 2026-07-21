library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_macunit_hybrid is
end entity;

architecture tb of tb_macunit_hybrid is

    constant DATA_WIDTH  : integer := 8; 
    constant INPUT_DATA_RADIX : integer := 4;  
    constant clk_period  : time := 10 ns;
    constant OUT_WIDTH   : integer := 32;

    constant INPUT_CYCLES : integer := DATA_WIDTH / INPUT_DATA_RADIX;

    constant OUTPUT_CYCLES : integer := OUT_WIDTH / INPUT_DATA_RADIX;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal en     : std_logic := '0';
    signal start  : std_logic := '0';
    signal load_w : std_logic := '0';

    signal w_in   : std_logic_vector(DATA_WIDTH-1 downto 0)  := (others => '0');
    signal x_in   : std_logic_vector(INPUT_DATA_RADIX-1 downto 0) := (others => '0'); 
    signal y_in   : std_logic_vector(INPUT_DATA_RADIX-1 downto 0) := (others => '0'); 

    signal x_out  : std_logic_vector(INPUT_DATA_RADIX-1 downto 0);
    signal y_out  : std_logic_vector(INPUT_DATA_RADIX-1 downto 0);
    signal en_out : std_logic;

begin

    clk <= not clk after clk_period/2;

    mac: entity work.macunit_hybrid
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            INPUT_DATA_RADIX => INPUT_DATA_RADIX
        )
        port map(
            clk    => clk,
            rst    => rst,
            en     => en,
            load_w => load_w,
            start  => start,
            w_in   => w_in,
            x_in   => x_in,
            y_in   => y_in,
            x_out  => x_out,
            y_out  => y_out,
            en_out => en_out
        );

    stim_proc: process
        variable input           : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable output          : std_logic_vector(OUT_WIDTH-1 downto 0);
        variable expected_output : std_logic_vector(OUT_WIDTH-1 downto 0);
        variable cycle_count     : integer;
        variable a : integer;
        variable b: integer;
    begin

        report "Hybrid Mac Unit Testbench";

        rst    <= '1';
        en     <= '0';
        load_w <= '0';
        y_in   <= (others => '0');
        x_in   <= (others => '0');

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- Weight (10 = 00001010)
        a := 10;
        b := 5;
        w_in   <= std_logic_vector(to_unsigned(a, DATA_WIDTH));
        load_w <= '1';
        wait until rising_edge(clk);
        load_w <= '0';

        -- input = 5 = 00000101
        -- output = 50
        -- first cycle 0101 goes to mac and then 2nd cycle 0000 goes into mac and 8 cycles to get 32bit output
        input := std_logic_vector(to_unsigned(b, DATA_WIDTH));

        en    <= '1';
        start <= '1';
        cycle_count := 0;

        for i in 0 to OUTPUT_CYCLES-1 loop

            if i < INPUT_CYCLES then
                x_in <= input((i+1)*INPUT_DATA_RADIX-1 downto i*INPUT_DATA_RADIX);
            else
                x_in <= (others => '0');
            end if;

            if i = 0 then
                start <= '1';
            else
                start <= '0';
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;

            output((i+1)*INPUT_DATA_RADIX-1 downto i*INPUT_DATA_RADIX) := y_out;

        end loop;

        if output = std_logic_vector(to_unsigned((a*b), OUT_WIDTH)) then
            report "correct " & integer'image(a) & " x " & integer'image(b) & " = " & integer'image(to_integer(unsigned(output)));
        else
            report "error got " & integer'image(to_integer(unsigned(output)))
                severity error;
        end if;
        
        en  <= '0';
        rst <= '1';

        report "All tests complete" severity failure;

        wait;
    end process;

end architecture;