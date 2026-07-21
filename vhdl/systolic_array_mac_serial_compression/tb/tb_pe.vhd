library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_processing_element is
end entity;


architecture tb of tb_processing_element is

    constant DATA_WIDTH : integer := 8;
    constant group_size : integer := 4;
    constant NO_OF_MAC : integer := 4;
    constant clk_period : time := 10 ns;
    constant ROWS : integer := 4;
    constant OUT_WIDTH : integer := 32;

    signal clk : std_logic := '0';
    signal rst : std_logic  := '0';
    signal en : std_logic  := '0';
    signal load_w : std_logic  := '0';
    signal w_in : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
    signal x_in : std_logic_vector(group_size-1 downto 0) := (others=>'0');
    signal y_in : std_logic_vector(NO_OF_MAC-1 downto 0) := (others=>'0');
    signal x_out : std_logic_vector(group_size-1 downto 0) := (others=>'0');
    signal y_out : std_logic_vector(NO_OF_MAC-1 downto 0) := (others=>'0');
    signal en_out : std_logic := '0';
    signal lut : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
    signal mac_valid_out : std_logic_vector(NO_OF_MAC-1 downto 0) := (others=>'0');
  

begin
 
    clk <= not clk after clk_period/2;

    pe: entity work.PE
        generic map( 
            DATA_WIDTH => DATA_WIDTH,
            group_size => group_size,
            ROWS => ROWS,
            NO_OF_MAC => NO_OF_MAC
        )
        port map(
            clk => clk,
            rst => rst,
            en => en,
            load_w => load_w,
            w_in => w_in,
            x_in => x_in,
            y_in => y_in,
            x_out => x_out,
            y_out => y_out,
            en_out => en_out,
            lut => lut,
            mac_valid_out => mac_valid_out
        );

 
    stim_proc: process

    variable full_input_stream : std_logic_vector(39 downto 0);

    variable output_1 : std_logic_vector(OUT_WIDTH-1 downto 0);
    variable output_2 : std_logic_vector(OUT_WIDTH-1 downto 0);
    variable output_3 : std_logic_vector(OUT_WIDTH-1 downto 0);
    variable output_4 : std_logic_vector(OUT_WIDTH-1 downto 0);
    variable output_5 : std_logic_vector(OUT_WIDTH-1 downto 0);

    variable expected_output : std_logic_vector(OUT_WIDTH-1 downto 0);
     
    begin 

        report " PE TB";

        rst <= '1';   -- reset
        en <= '0';
        load_w <= '0';
        y_in <= (others=>'0');
        x_in <= (others=>'0');

        wait for 30 ns;
        wait until rising_edge(clk);
        rst <='0';
        wait until rising_edge(clk);

        lut <= std_logic_vector(to_unsigned(0, DATA_WIDTH));  

        w_in <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
        load_w <= '1';
        wait until rising_edge(clk);
        load_w <= '0';

        full_input_stream(7 downto 0) := std_logic_vector(to_unsigned(4, DATA_WIDTH));
        full_input_stream(15 downto 8) := std_logic_vector(to_unsigned(5, DATA_WIDTH));
        full_input_stream(23 downto 16) := std_logic_vector(to_unsigned(6, DATA_WIDTH));
        full_input_stream(31 downto 24) := std_logic_vector(to_unsigned(7, DATA_WIDTH));
        full_input_stream(39 downto 32) := std_logic_vector(to_unsigned(8, DATA_WIDTH)); 

        en <= '1';
        for i in 0 to 64 loop 
            
            if i < 40 then 
                x_in(0) <= full_input_stream(i);
            else
                x_in(0) <= '0';
            end if;
            
            wait until rising_edge(clk);
            wait for 1 ns;
            
            if i >= 1 and i < 33 then
                output_1(i - 1) := y_out(0);
            end if;

            if i >= 9 and i < 41 then
                output_2(i - 9) := y_out(1);
            end if;

            if i >= 17 and i < 49 then
                output_3(i - 17) := y_out(2);
            end if;

            if i >= 25 and i < 57 then
                output_4(i - 25) := y_out(3);
            end if;

            if i >= 33 and i < 65 then
                output_5(i - 33) := y_out(0);
            end if;
        end loop;

        report "MAC 0 Result (10 * 4): " & integer'image(to_integer(unsigned(output_1)));
        report "MAC 1 Result (10 * 5): " & integer'image(to_integer(unsigned(output_2)));
        report "MAC 2 Result (10 * 6): " & integer'image(to_integer(unsigned(output_3)));
        report "MAC 3 Result (10 * 7): " & integer'image(to_integer(unsigned(output_4)));
        report "MAC 0 Result (10 * 8): " & integer'image(to_integer(unsigned(output_5)));


        if to_integer(unsigned(output_1)) = 40 and 
           to_integer(unsigned(output_2)) = 50 and 
           to_integer(unsigned(output_3)) = 60 and 
           to_integer(unsigned(output_4)) = 70 and 
           to_integer(unsigned(output_5)) = 80 then            
            report "Correct";
        else
            report "Error" severity error;
        end if;

        en <= '0'; 
        wait;
    end process;
end architecture;