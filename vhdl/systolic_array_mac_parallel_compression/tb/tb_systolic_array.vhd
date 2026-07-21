library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_systolicarray is
end entity tb_systolicarray;

architecture rtl of tb_systolicarray is
    constant DATA_WIDTH : positive := 8;
    constant OUT_WIDTH  : positive := 32;
    constant group_size : positive := 16;
    constant ROWS       : positive := 32;
    constant COLS       : positive := 32;
    constant NO_OF_MAC  : positive := 4;
    constant clk_period : time := 10 ns;

    constant ACTIVE_COLS : positive := COLS / group_size;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal load_weight  : std_logic := '0';
    signal x_bottom_bus : std_logic_vector(group_size*COLS*DATA_WIDTH-1 downto 0) := (others => '0');
    signal w_mat        : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0) := (others => '0');
    signal lut_mat      : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0) := (others => '0');
    signal y_out_bus    : std_logic_vector(ROWS*OUT_WIDTH-1 downto 0) := (others => '0');

begin

    clk <= not clk after clk_period/2;

    systolicarray : entity work.SystolicArray
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            OUT_WIDTH  => OUT_WIDTH,
            group_size => group_size,
            ROWS       => ROWS,
            COLS       => COLS
        )
        port map (
            clk          => clk,
            rst          => rst,
            load_weight  => load_weight,
            x_bottom_bus => x_bottom_bus,
            w_mat        => w_mat,
            lut_mat      => lut_mat,
            y_out_bus    => y_out_bus
        );

    stim_process : process
        variable w_id        : integer := 0;
        variable input_id    : integer := 0;
        variable lut_val     : integer := 0;
        variable correct     : boolean := true;

        variable out0        : integer := 0;
        variable out1        : integer := 0;
        variable out2        : integer := 0;
        variable out3        : integer := 0;

        constant EXPECTED0   : integer := 10 * 4 * ACTIVE_COLS;
        constant EXPECTED1   : integer := 10 * 5 * ACTIVE_COLS;
        constant EXPECTED2   : integer := 10 * 6 * ACTIVE_COLS;
        constant EXPECTED3   : integer := 10 * 7 * ACTIVE_COLS;

        constant LAST_OUTPUT_CYCLE : integer := (NO_OF_MAC - 1) + (COLS - 1) + (ROWS - 1);
        constant TOTAL_CYCLES      : integer := LAST_OUTPUT_CYCLE;
        variable value_for_mac : integer := 0;
    begin

        report "Systolic Array Parallel TB (group_size=" & integer'image(group_size) & ")";

        rst          <= '1';
        load_weight  <= '0';
        x_bottom_bus <= (others => '0');
        w_mat        <= (others => '0');
        lut_mat      <= (others => '0');
        wait for 20 ns;

        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        for r in 0 to ROWS-1 loop
            for c in 0 to COLS-1 loop
                w_id := r*COLS + c;

                if c < ACTIVE_COLS then
                    w_mat((w_id+1)*DATA_WIDTH-1 downto w_id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(10, DATA_WIDTH));

                    lut_mat((w_id+1)*DATA_WIDTH-1 downto w_id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(c mod group_size, DATA_WIDTH));
                else
                    w_mat((w_id+1)*DATA_WIDTH-1 downto w_id*DATA_WIDTH) <=
                        (others => '0');

                    lut_mat((w_id+1)*DATA_WIDTH-1 downto w_id*DATA_WIDTH) <=
                        (others => '0');
                end if;
            end loop;
        end loop;

        load_weight <= '1';
        wait until rising_edge(clk);
        load_weight <= '0';

        for i in 0 to TOTAL_CYCLES loop
            x_bottom_bus <= (others => '0');

            for m in 0 to NO_OF_MAC-1 loop
                for c in 0 to ACTIVE_COLS-1 loop
                    if i = c + m then
                        lut_val := c mod group_size;
                        value_for_mac := 4 + m;

                        for g in 0 to group_size-1 loop
                            input_id := c*group_size + g;

                            if g = lut_val then
                                x_bottom_bus((input_id+1)*DATA_WIDTH-1 downto input_id*DATA_WIDTH) <=
                                    std_logic_vector(to_signed(value_for_mac, DATA_WIDTH));
                            else
                                x_bottom_bus((input_id+1)*DATA_WIDTH-1 downto input_id*DATA_WIDTH) <=
                                    (others => '0');
                            end if;
                        end loop;
                    end if;
                end loop;
            end loop;

            wait until rising_edge(clk);
            wait for 1 ns;

            for r in 0 to ROWS-1 loop
                if i = (0 + (COLS-1) + r) then
                    out0 := to_integer(signed(y_out_bus((r+1)*OUT_WIDTH-1 downto r*OUT_WIDTH)));
                    report "Row " & integer'image(r) & " MAC0 output: " & integer'image(out0);
                    if out0 /= EXPECTED0 then
                        correct := false;
                    end if;
                end if;

                if i = (1 + (COLS-1) + r) then
                    out1 := to_integer(signed(y_out_bus((r+1)*OUT_WIDTH-1 downto r*OUT_WIDTH)));
                    report "Row " & integer'image(r) & " MAC1 output: " & integer'image(out1);
                    if out1 /= EXPECTED1 then
                        correct := false;
                    end if;
                end if;

                if i = (2 + (COLS-1) + r) then
                    out2 := to_integer(signed(y_out_bus((r+1)*OUT_WIDTH-1 downto r*OUT_WIDTH)));
                    report "Row " & integer'image(r) & " MAC2 output: " & integer'image(out2);
                    if out2 /= EXPECTED2 then
                        correct := false;
                    end if;
                end if;

                if i = (3 + (COLS-1) + r) then
                    out3 := to_integer(signed(y_out_bus((r+1)*OUT_WIDTH-1 downto r*OUT_WIDTH)));
                    report "Row " & integer'image(r) & " MAC3 output: " & integer'image(out3);
                    if out3 /= EXPECTED3 then
                        correct := false;
                    end if;
                end if;
            end loop;
        end loop;

        if correct then
            report "Correct: MAC0=" & integer'image(EXPECTED0) & ", MAC1=" & integer'image(EXPECTED1) &
                   ", MAC2=" & integer'image(EXPECTED2) & ", MAC3=" & integer'image(EXPECTED3);
        else
            report "error" severity error;
        end if;

        report "End simulation" severity failure;

    end process;

end architecture;