library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_macunit_serial is
end entity;

architecture tb of tb_macunit_serial is

    constant DATA_WIDTH : integer := 8;
    constant clk_period : time := 10 ns;
    constant OUT_WIDTH : integer := 32;


    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal en : std_logic := '0';
    signal start : std_logic := '0';
    signal load_w : std_logic := '0';

    signal w_in : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
    signal x_in : std_logic;
    signal y_in : std_logic;

    signal x_out : std_logic;
    signal y_out : std_logic;
    signal en_out : std_logic;

begin


    clk <= not clk after clk_period/2;

    -- MACUNIT
    mac: entity work.macunit_serial
        generic map( 
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,
            en => en,
            load_w => load_w,
            start => start,
            w_in => w_in,
            x_in => x_in,
            y_in => y_in,
            x_out => x_out,
            y_out => y_out,
            en_out => en_out
    );

    stim_proc: process
    variable input : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable output : std_logic_vector(OUT_WIDTH-1 downto 0);
    variable expected_output : std_logic_vector(OUT_WIDTH-1 downto 0);
    begin

        report " MAC TB ";

        rst <= '1';   -- reset everything
        en <= '0';
        load_w <= '0';
        y_in <= '0'; 
        x_in <= '0'; 

        wait for 30 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- Weight loading
        w_in <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
        load_w <= '1';
        wait until rising_edge(clk);
        load_w <= '0'; 

        -- start compute
        input := std_logic_vector(to_unsigned(5, DATA_WIDTH));

        en <= '1';
        start <= '1';
        x_in <= input(0);
        wait until rising_edge(clk);
        start <= '0'; 
        wait for 1 ns;
        output(0) := y_out;

        for i in 1 to OUT_WIDTH-1 loop 
            if i < DATA_WIDTH then 
                x_in <= input(i);
            else
                x_in <= '0';
            end if;
            wait until rising_edge(clk);
            wait for 1 ns;
            output(i) := y_out;
        end loop; 
        expected_output := std_logic_vector(to_unsigned(50, OUT_WIDTH));


        -- result expected is weight = 3 and input = 2 so 3*2 = 6
        if output=expected_output then
            report "Correct and value is " & integer'image(to_integer(unsigned(output)));
        else
            report " Fail" & integer'image(to_integer(unsigned(output))) SEVERITY error;
        end if;

        en <= '0'; 
        rst <= '1';

        wait;
    end process;
end architecture;