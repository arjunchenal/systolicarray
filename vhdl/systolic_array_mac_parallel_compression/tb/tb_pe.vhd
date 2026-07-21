library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pe is 
end entity tb_pe;

architecture rtl of tb_pe is 
    constant DATA_WIDTH : integer := 8;
    constant OUT_WIDTH : integer := 32;
    constant group_size : integer := 2;

    constant clk_period : time := 10 ns;

       signal clk               : std_logic := '0';
       signal rst           : std_logic := '1';
       signal en            : std_logic := '1';
       signal load_w        : std_logic := '0';
       signal w_in          : signed(DATA_WIDTH-1 downto 0) := (others => '0');
       signal x_in          : signed(group_size*DATA_WIDTH-1 downto 0) := (others => '0');
       signal y_in          : signed(OUT_WIDTH-1 downto 0) := (others => '0');
       signal x_out         : signed(group_size*DATA_WIDTH-1 downto 0) := (others => '0');
       signal y_out         : signed(OUT_WIDTH-1 downto 0) := (others => '0');
       signal lut           : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    clk <= not clk after clk_period/2;

    pe : entity work.PE
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            OUT_WIDTH => OUT_WIDTH,
            group_size => group_size
        )
        port map (
            clk => clk,
            rst => rst,
            en => en,
            load_w => load_w,
            w_in => w_in,
            x_in => x_in,
            x_out => x_out,
            y_in => y_in,
            y_out => y_out,
            lut => lut
        );

    stim_process : process
    variable expected_output : integer := 0;
    begin

        report " Processing element parallel ";

        rst <= '1'; 
        en <= '1';
        load_w <= '0';
        x_in <= (others=>'0');
        w_in <= (others=>'0');
        lut    <= (others=>'0');
        y_in <= (others=>'0');
        wait for 20 ns;


        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);


        w_in <= to_signed(3, DATA_WIDTH);
        lut <= to_unsigned(0, DATA_WIDTH);
        load_w <= '1'; 
        wait until rising_edge(clk);
        load_w <= '0'; 

        x_in <= to_signed(4, group_size*DATA_WIDTH);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        report "The output is : " &integer'image(to_integer(y_out));
        wait;
        
    end process;



end architecture;