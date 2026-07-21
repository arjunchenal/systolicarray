
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pe_grid is
end entity tb_pe_grid;

architecture tb of tb_pe_grid is

    constant DATA_WIDTH            : integer := 8;
    constant ROWS                  : integer := 32;
    constant COLS                  : integer := 32;
    constant NO_OF_MAC             : integer := 4;
    constant group_size            : integer := 1;
    constant clk_period            : time    := 10 ns;
    constant OUT_WIDTH             : integer := 32;
    constant MAX_OUTPUT_ROWS_WIDTH : integer := 5;

    constant LATENCY      : integer := COLS;
    constant ACTIVE_COLS  : integer := COLS / group_size;
    
    constant TOTAL_CYCLES : integer := LATENCY + (ROWS - 1) +(NO_OF_MAC - 1)*DATA_WIDTH + OUT_WIDTH + ACTIVE_COLS + 30;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal en          : std_logic := '0';
    signal load_w      : std_logic := '0';

    signal x_col_bits      : std_logic_vector((COLS*group_size)-1 downto 0);
    signal w_mat           : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal lut_mat         : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal lane_valid_bits : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);

    signal y_row_bits      : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);
    signal row_id_data_in  : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
    signal row_id_data_out : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);

begin

    clk <= not clk after clk_period/2;

    systolic_array: entity work.SystolicArray_serial
        generic map (
            DATA_WIDTH             => DATA_WIDTH,
            ROWS                   => ROWS,
            COLS                   => COLS,
            group_size             => group_size,
            MAX_OUTPUT_ROWS_WIDTH  => MAX_OUTPUT_ROWS_WIDTH,
            NO_OF_MAC              => NO_OF_MAC
        )
        port map (
            clk             => clk,
            rst             => rst,
            en              => en,
            load_w          => load_w,
            x_col_bits      => x_col_bits,
            w_mat           => w_mat,
            lut_mat         => lut_mat,
            y_row_bits      => y_row_bits,
            lane_valid_bits => lane_valid_bits,
            row_id_data_in  => row_id_data_in,
            row_id_data_out => row_id_data_out
        );

    stim_proc: process
        variable input        : std_logic_vector(31 downto 0);
        variable id           : integer;
        variable mac_start    : integer;
        variable correct      : boolean := true;

        type mac_result_t  is array (0 to NO_OF_MAC-1) of std_logic_vector(OUT_WIDTH-1 downto 0);
        type grid_result_t is array (0 to ROWS-1) of mac_result_t;
        variable grid_out : grid_result_t;

        constant EXP0 : integer := 10 * 2 * ACTIVE_COLS;
        constant EXP1 : integer := 10 * 5 * ACTIVE_COLS;
        constant EXP2 : integer := 10 * 6 * ACTIVE_COLS;
        constant EXP3 : integer := 10 * 7 * ACTIVE_COLS;
    begin

        report "Systolic Array GRID TB (group_size=" & integer'image(group_size) & ")";
        rst        <= '1';
        en         <= '0';
        load_w     <= '0';
        x_col_bits <= (others => '0');
        w_mat      <= (others => '0');
        lut_mat    <= (others => '0');

        -- wait for 30 ns;
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);
        for r in 0 to ROWS-1 loop
            for c in 0 to COLS-1 loop
                id := r*COLS + c;

                if c < ACTIVE_COLS then
                    w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(10, DATA_WIDTH));
                    lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(c mod group_size, DATA_WIDTH));
                else
                    w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
                    lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
                end if;
            end loop;
        end loop;

        load_w <= '1';
        wait until rising_edge(clk);

        load_w <= '0';

        input(7  downto  0) := std_logic_vector(to_unsigned(2, DATA_WIDTH));
        input(15 downto  8) := std_logic_vector(to_unsigned(5, DATA_WIDTH));
        input(23 downto 16) := std_logic_vector(to_unsigned(6, DATA_WIDTH));
        input(31 downto 24) := std_logic_vector(to_unsigned(7, DATA_WIDTH));

        en <= '1';

        for i in 0 to TOTAL_CYCLES loop

            x_col_bits <= (others => '0');

            for c in 0 to ACTIVE_COLS-1 loop
                if i >= c and i < (32 + c) then
                    x_col_bits(c * group_size + (c mod group_size)) <= input(i - c);
                end if;
            end loop;

            wait until rising_edge(clk);
            wait for 1 ns;

            for r in 0 to ROWS-1 loop
                for m in 0 to NO_OF_MAC-1 loop
                    mac_start := LATENCY + (2*r) + m*DATA_WIDTH;
                    if i >= mac_start and i < (mac_start + OUT_WIDTH) then
                        grid_out(r)(m)(i - mac_start) := y_row_bits(r*NO_OF_MAC + m);
                    end if;
                end loop;
            end loop;

        end loop;

        en <= '0';

        for r in 0 to ROWS-1 loop
            if to_integer(unsigned(grid_out(r)(0))) /= EXP0 or to_integer(unsigned(grid_out(r)(1))) /= EXP1 or
               to_integer(unsigned(grid_out(r)(2))) /= EXP2 or to_integer(unsigned(grid_out(r)(3))) /= EXP3 then
                correct := false;
                report " " & integer'image(r) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(3)))) & " error";
            else
                report " " & integer'image(r) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(3)))) & " true";
            end if;
        end loop;

        if correct then
            report "correct";
        else
            report "error" severity error;
        end if;

        report "End simulation" severity failure;

    end process stim_proc;

end architecture tb;