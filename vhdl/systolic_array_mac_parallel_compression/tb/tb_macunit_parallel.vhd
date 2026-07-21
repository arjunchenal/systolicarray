library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_macunit_parallel is 
end entity tb_macunit_parallel;

architecture rtl of tb_macunit_parallel is 
    constant DATA_WIDTH : integer := 8;
    constant OUT_WIDTH : integer := 32;

    constant clk_period : time := 10 ns;

    signal clk    : std_logic := '0';
    signal  rst   : std_logic := '1';
    signal  x     :  signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal  w     :  signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal load_weight :  std_logic := '0';
    signal  partial_sum_in :  signed(OUT_WIDTH-1 downto 0) := (others => '0');
    signal partial_sum_out :  signed(OUT_WIDTH-1 downto 0) := (others => '0');
    signal x_out :  signed(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    clk <= not clk after clk_period/2;

    macunit : entity work.MacUnit_parallel
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            OUT_WIDTH => OUT_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            load_weight => load_weight,
            x => x,
            w => w,
            partial_sum_in => partial_sum_in,
            partial_sum_out => partial_sum_out,
            x_out => x_out
        );

    stim_process : process
    variable expected_output : integer := 0;
    begin

        report " Mac parallel ";

        rst <= '1'; 
        load_weight <= '0';
        x <= (others=>'0');
        w <= (others=>'0');
        wait for 20 ns;


        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);


        w <= to_signed(3, DATA_WIDTH);
        load_weight <= '1'; 
        wait until rising_edge(clk);
        load_weight <= '0'; 

        x <= to_signed(5, DATA_WIDTH);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        report "The output is : " &integer'image(to_integer(partial_sum_out));
        wait;
        
    end process;



end architecture;