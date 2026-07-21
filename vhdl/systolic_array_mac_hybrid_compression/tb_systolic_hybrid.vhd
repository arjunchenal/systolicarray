
-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;

-- entity tb_pe_grid is
-- end entity tb_pe_grid;

-- architecture tb of tb_pe_grid is

--     constant DATA_WIDTH            : integer := 8;
--     constant ROWS                  : integer := 32;
--     constant COLS                  : integer := 32;
--     constant NO_OF_MAC             : integer := 2;
--     constant group_size            : integer := 1;
--     constant clk_period            : time    := 10 ns;
--     constant OUT_WIDTH             : integer := 32;
--     constant MAX_OUTPUT_ROWS_WIDTH : integer := 5;
--     constant INPUT_DATA_RADIX : integer := 4;

--     constant LATENCY      : integer := COLS;
--     constant ACTIVE_COLS  : integer := COLS / group_size;
    
--     constant TOTAL_CYCLES : integer := LATENCY + (ROWS - 1) +(NO_OF_MAC - 1)*DATA_WIDTH + OUT_WIDTH + ACTIVE_COLS + 30;

--     signal clk         : std_logic := '0';
--     signal rst         : std_logic := '1';
--     signal en          : std_logic := '0';
--     signal load_w      : std_logic := '0';

--     signal x_col_bits      : std_logic_vector((COLS*group_size*INPUT_DATA_RADIX)-1 downto 0);
--     signal w_mat           : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
--     signal lut_mat         : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
--     signal lane_valid_bits : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);

--     signal y_row_bits      : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);
--     signal row_id_data_in  : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
--     signal row_id_data_out : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);

-- begin

--     clk <= not clk after clk_period/2;

--     systolic_array: entity work.SystolicArray_hybrid
--         generic map (
--             DATA_WIDTH             => DATA_WIDTH,
--             ROWS                   => ROWS,
--             COLS                   => COLS,
--             group_size             => group_size,
--             MAX_OUTPUT_ROWS_WIDTH  => MAX_OUTPUT_ROWS_WIDTH,
--             NO_OF_MAC              => NO_OF_MAC,
--             INPUT_DATA_RADIX => INPUT_DATA_RADIX
--         )
--         port map (
--             clk             => clk,
--             rst             => rst,
--             en              => en,
--             load_w          => load_w,
--             x_col_bits      => x_col_bits,
--             w_mat           => w_mat,
--             lut_mat         => lut_mat,
--             y_row_bits      => y_row_bits,
--             lane_valid_bits => lane_valid_bits,
--             row_id_data_in  => row_id_data_in,
--             row_id_data_out => row_id_data_out
--         );

--     stim_proc: process
--         variable input        : std_logic_vector(31 downto 0);
--         variable id           : integer;
--         variable mac_start    : integer;
--         variable correct      : boolean := true;

--         type mac_result_t  is array (0 to NO_OF_MAC-1) of std_logic_vector(OUT_WIDTH-1 downto 0);
--         type grid_result_t is array (0 to ROWS-1) of mac_result_t;
--         variable grid_out : grid_result_t;

--         constant EXP0 : integer := 10 * 2 * ACTIVE_COLS;
--         constant EXP1 : integer := 10 * 5 * ACTIVE_COLS;
--         constant EXP2 : integer := 10 * 6 * ACTIVE_COLS;
--         constant EXP3 : integer := 10 * 7 * ACTIVE_COLS;
--     begin

--         report "Systolic Array GRID TB (group_size=" & integer'image(group_size) & ")";
--         rst        <= '1';
--         en         <= '0';
--         load_w     <= '0';
--         x_col_bits <= (others => '0');
--         w_mat      <= (others => '0');
--         lut_mat    <= (others => '0');

--         -- wait for 30 ns;
--         wait until rising_edge(clk);
--         wait until rising_edge(clk);
--         wait until rising_edge(clk);

--         wait until rising_edge(clk);
--         rst <= '0';
--         wait until rising_edge(clk);
--         for r in 0 to ROWS-1 loop
--             for c in 0 to COLS-1 loop
--                 id := r*COLS + c;

--                 if c < ACTIVE_COLS then
--                     w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
--                         std_logic_vector(to_unsigned(10, DATA_WIDTH));
--                     lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
--                         std_logic_vector(to_unsigned(c mod group_size, DATA_WIDTH));
--                 else
--                     w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
--                     lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
--                 end if;
--             end loop;
--         end loop;

--         load_w <= '1';
--         wait until rising_edge(clk);

--         load_w <= '0';

--         input(7  downto  0) := std_logic_vector(to_unsigned(2, DATA_WIDTH));
--         input(15 downto  8) := std_logic_vector(to_unsigned(5, DATA_WIDTH));
--         input(23 downto 16) := std_logic_vector(to_unsigned(6, DATA_WIDTH));
--         input(31 downto 24) := std_logic_vector(to_unsigned(7, DATA_WIDTH));

--         en <= '1';

--         for i in 0 to TOTAL_CYCLES loop

--             x_col_bits <= (others => '0');

--             for c in 0 to ACTIVE_COLS-1 loop 
--                 if i >= c and i < ((OUT_WIDTH/INPUT_DATA_RADIX) + c) then
--                     if a
--                         x_col_bits((c+1)*INPUT_DATA_RADIX-1  downto c*INPUT_DATA_RADIX) <= input(((i-c)+1)*INPUT_DATA_RADIX-1 - (i-c)*INPUT_DATA_RADIX);
--                     else 
--                         x_col_bits()
--                     end if;
--                 end if;
--             end loop;




--             wait until rising_edge(clk);
--             wait for 1 ns;

--             for r in 0 to ROWS-1 loop
--                 for m in 0 to NO_OF_MAC-1 loop
--                     mac_start := LATENCY + (2*r) + m*DATA_WIDTH;
--                     if i >= mac_start and i < (mac_start + OUT_WIDTH) then
--                         grid_out(r)(m)(i - mac_start) := y_row_bits(r*NO_OF_MAC + m);
--                     end if;
--                 end loop;
--             end loop;

--         end loop;

--         en <= '0';

--         for r in 0 to ROWS-1 loop
--             if to_integer(unsigned(grid_out(r)(0))) /= EXP0 or to_integer(unsigned(grid_out(r)(1))) /= EXP1 or
--                to_integer(unsigned(grid_out(r)(2))) /= EXP2 or to_integer(unsigned(grid_out(r)(3))) /= EXP3 then
--                 correct := false;
--                 report " " & integer'image(r) & " "
--                      & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
--                      & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(3)))) & " error";
--             else
--                 report " " & integer'image(r) & " "
--                      & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
--                      & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " " & integer'image(to_integer(unsigned(grid_out(r)(3)))) & " true";
--             end if;
--         end loop;

--         if correct then
--             report "correct";
--         else
--             report "error" severity error;
--         end if;

--         report "End simulation" severity failure;

--     end process stim_proc;

-- end architecture tb;

















library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_systolic_hybrid is
end entity tb_systolic_hybrid;

architecture tb of tb_systolic_hybrid is

    constant DATA_WIDTH            : integer := 8;
    constant ROWS                  : integer := 32;
    constant COLS                  : integer := 32;
    constant NO_OF_MAC             : integer := 2;
    constant group_size            : integer := 16;
    constant clk_period            : time    := 10 ns;
    constant OUT_WIDTH             : integer := 32;
    constant MAX_OUTPUT_ROWS_WIDTH : integer := 3;
    constant INPUT_DATA_RADIX      : integer := 4;

    constant NUM_INPUTS        : integer := 4;
    constant TIMER_WIDTH       : integer := 3;
    constant PERIOD            : integer := 2**TIMER_WIDTH;          
    constant LATENCY           : integer := COLS;                 
    constant ACTIVE_COLS       : integer := COLS / group_size;       
    constant CYCLES_PER_INPUT  : integer := DATA_WIDTH / INPUT_DATA_RADIX;  
    constant OUTPUT_CYCLES     : integer := OUT_WIDTH  / INPUT_DATA_RADIX;  
    constant ACTIVE_PER_PERIOD : integer := NO_OF_MAC * CYCLES_PER_INPUT;   
    constant NUM_PERIODS       : integer := NUM_INPUTS / NO_OF_MAC;  
    constant TOTAL_RESULTS     : integer := NUM_INPUTS;               

    constant TOTAL_CYCLES : integer := LATENCY
                                     + (NUM_PERIODS - 1) * PERIOD
                                     + NO_OF_MAC * CYCLES_PER_INPUT
                                     + 2 * (ROWS - 1)
                                     + OUTPUT_CYCLES
                                     + ACTIVE_COLS
                                     + 30;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal en          : std_logic := '0';
    signal load_w      : std_logic := '0';

    signal x_col_bits      : std_logic_vector((COLS*group_size*INPUT_DATA_RADIX)-1 downto 0);
    signal w_mat           : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal lut_mat         : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal lane_valid_bits : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);
    signal y_row_bits      : std_logic_vector(ROWS*INPUT_DATA_RADIX*NO_OF_MAC-1 downto 0);
    signal row_id_data_in  : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
    signal row_id_data_out : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);

begin

    clk <= not clk after clk_period/2;

    systolic_array : entity work.SystolicArray_hybrid
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

    stim_proc : process

        constant TOTAL_NIBBLES : integer := NUM_INPUTS * CYCLES_PER_INPUT;  -- 8

        type nibble_array_t is array (0 to TOTAL_NIBBLES-1) of
            std_logic_vector(INPUT_DATA_RADIX-1 downto 0);
        variable nibble_stream : nibble_array_t;

        variable id            : integer;
        variable correct       : boolean := true;
        variable rel           : integer;
        variable period_num    : integer;
        variable pos_in_period : integer;
        variable nibble_idx    : integer;


        variable p          : integer;
        variable m          : integer;
        variable mac_start  : integer;

        type result_array_t is array (0 to TOTAL_RESULTS-1) of
            std_logic_vector(OUT_WIDTH-1 downto 0);
        type grid_result_t  is array (0 to ROWS-1) of result_array_t;
        variable grid_out : grid_result_t := (others => (others => (others => '0')));

        type exp_array_t is array (0 to TOTAL_RESULTS-1) of integer;
        constant EXP : exp_array_t := (
            10 * 2 * ACTIVE_COLS,   
            10 * 5 * ACTIVE_COLS,  
            10 * 6 * ACTIVE_COLS,   
            10 * 7 * ACTIVE_COLS    
        );

    begin

        report "=== Hybrid Systolic TB ==="
             & " NO_OF_MAC="        & integer'image(NO_OF_MAC)
             & " NUM_INPUTS="       & integer'image(NUM_INPUTS)
             & " NUM_PERIODS="      & integer'image(NUM_PERIODS)
             & " PERIOD="           & integer'image(PERIOD)
             & " TOTAL_CYCLES="     & integer'image(TOTAL_CYCLES);
        report "Expected per row: "
             & integer'image(EXP(0)) & " "
             & integer'image(EXP(1)) & " "
             & integer'image(EXP(2)) & " "
             & integer'image(EXP(3));

        nibble_stream(0) := std_logic_vector(to_unsigned(2 mod 16, INPUT_DATA_RADIX));
        nibble_stream(1) := std_logic_vector(to_unsigned(2  /  16, INPUT_DATA_RADIX));
        nibble_stream(2) := std_logic_vector(to_unsigned(5 mod 16, INPUT_DATA_RADIX));
        nibble_stream(3) := std_logic_vector(to_unsigned(5  /  16, INPUT_DATA_RADIX));
        nibble_stream(4) := std_logic_vector(to_unsigned(6 mod 16, INPUT_DATA_RADIX));
        nibble_stream(5) := std_logic_vector(to_unsigned(6  /  16, INPUT_DATA_RADIX));
        nibble_stream(6) := std_logic_vector(to_unsigned(7 mod 16, INPUT_DATA_RADIX));
        nibble_stream(7) := std_logic_vector(to_unsigned(7  /  16, INPUT_DATA_RADIX));

        -- Reset
        rst            <= '1';
        en             <= '0';
        load_w         <= '0';
        x_col_bits     <= (others => '0');
        w_mat          <= (others => '0');
        lut_mat        <= (others => '0');
        row_id_data_in <= (others => '0');

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
                    w_mat  ((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(10, DATA_WIDTH));
                    lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <=
                        std_logic_vector(to_unsigned(c mod group_size, DATA_WIDTH));
                else
                    w_mat  ((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
                    lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= (others => '0');
                end if;
            end loop;
        end loop;

        load_w <= '1';
        wait until rising_edge(clk);
        load_w <= '0';

        en <= '1';

        for i in 0 to TOTAL_CYCLES loop

            x_col_bits <= (others => '0');

            for c in 0 to ACTIVE_COLS-1 loop
                if i >= c then
                    rel := i - c;
                    if rel < NUM_PERIODS * PERIOD then
                        period_num    := rel / PERIOD;
                        pos_in_period := rel mod PERIOD;

                        if pos_in_period < ACTIVE_PER_PERIOD then
                            nibble_idx := period_num * ACTIVE_PER_PERIOD
                                          + pos_in_period;
                            if nibble_idx < TOTAL_NIBBLES then
                                x_col_bits(
                                    (c*group_size+(c mod group_size)+1)*INPUT_DATA_RADIX-1
                                    downto
                                    (c*group_size+(c mod group_size))*INPUT_DATA_RADIX
                                ) <= nibble_stream(nibble_idx);
                            end if;
                        end if;
                    end if;
                end if;
            end loop;

            wait until rising_edge(clk);
            wait for 1 ns;

            for r in 0 to ROWS-1 loop
                for k in 0 to TOTAL_RESULTS-1 loop
                    p := k / NO_OF_MAC;    
                    m := k mod NO_OF_MAC;

                    mac_start := LATENCY + p * PERIOD + (m + 1) * CYCLES_PER_INPUT - 2 + 2 * r;

                    if i >= mac_start and i < (mac_start + OUTPUT_CYCLES) then

                        for b in 0 to INPUT_DATA_RADIX-1 loop
                            grid_out(r)(k)(
                                (i - mac_start) * INPUT_DATA_RADIX + b
                            ) := y_row_bits(
                                    r * NO_OF_MAC * INPUT_DATA_RADIX
                                    + m * INPUT_DATA_RADIX
                                    + b
                                 );
                        end loop;
                    end if;

                end loop;
            end loop;
        end loop;

        en <= '0';

        for r in 0 to ROWS-1 loop
            correct := true;
            for k in 0 to TOTAL_RESULTS-1 loop
                if to_integer(unsigned(grid_out(r)(k))) /= EXP(k) then
                    correct := false;
                end if;
            end loop;

            if not correct then
                report "row " & integer'image(r)
                     & " got: "
                     & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(3))))
                     & " expected: "
                     & integer'image(EXP(0)) & " "
                     & integer'image(EXP(1)) & " "
                     & integer'image(EXP(2)) & " "
                     & integer'image(EXP(3))
                     & " FAIL" severity warning;
            else
                report "row " & integer'image(r)
                     & " ["
                     & integer'image(to_integer(unsigned(grid_out(r)(0)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(1)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(2)))) & " "
                     & integer'image(to_integer(unsigned(grid_out(r)(3))))
                     & "] PASS";
            end if;
        end loop;

        report "End simulation" severity failure;
    end process stim_proc;

end architecture tb;
