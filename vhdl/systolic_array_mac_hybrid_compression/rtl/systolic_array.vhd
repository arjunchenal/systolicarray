library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SystolicArray_hybrid is
    generic (
        ROWS : positive := 32;
        COLS : positive := 32;
        DATA_WIDTH : positive := 8;
        group_size : positive := 16;
        NO_OF_MAC : positive := 2;
        MAX_OUTPUT_ROWS_WIDTH : positive := 3;
        INPUT_DATA_RADIX : positive := 4
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        en     : in  std_logic;
        load_w : in  std_logic;
        x_col_bits : in  std_logic_vector((COLS*group_size*INPUT_DATA_RADIX)-1 downto 0);
        w_mat  : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        y_row_bits : out std_logic_vector(ROWS*INPUT_DATA_RADIX*NO_OF_MAC-1 downto 0);
        lut_mat    : in std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        lane_valid_bits : out std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);
        row_id_data_in : in std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
        row_id_data_out : out std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of SystolicArray_hybrid is
    subtype input_group is std_logic_vector(group_size*INPUT_DATA_RADIX-1 downto 0);

    type x_mat is array (0 to ROWS-1, 0 to COLS-1) of input_group;
    type y_mat is array (0 to ROWS-1, 0 to COLS-1) of std_logic_vector(INPUT_DATA_RADIX*NO_OF_MAC-1 downto 0);
    type w_matrix is array (0 to ROWS-1, 0 to COLS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type lut_matrix is array (0 to ROWS-1, 0 to COLS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type std_logic_mat is array (0 to ROWS-1, 0 to COLS-1) of std_logic;
    type row_bus is array (0 to ROWS-1) of std_logic_vector(INPUT_DATA_RADIX*NO_OF_MAC-1 downto 0);
    type v_matrix is array (0 to ROWS-1, 0 to COLS-1) of std_logic_vector(NO_OF_MAC-1 downto 0);
    type delay_array is array(0 to COLS-1) of std_logic_vector(COLS-1 downto 0);
    type row_id_array is array(0 to ROWS-1) of std_logic_vector(MAX_OUTPUT_ROWS_WIDTH-1 downto 0);

    signal x_in, x_out : x_mat;
    signal y_in, y_out : y_mat;
    signal w_pe        : w_matrix;
    signal lut_pe      : lut_matrix;
    signal en_internal : std_logic_mat;
    signal en_next     : std_logic_mat;
    signal y_raw       : row_bus;
    signal v_mat       : v_matrix;

    signal en_delay_line  : delay_array;
    signal en_row0_skewed : std_logic_vector(COLS-1 downto 0);

    signal row_data_reg : row_id_array;

    signal x_up_delay  : x_mat;
    signal en_up_delay : std_logic_mat;

    signal load_w_reg    : std_logic;
    signal row_id_in_reg : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);

begin


    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                load_w_reg <= '0';
            else
                load_w_reg <= load_w;
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                row_id_in_reg <= (others => '0');
            else
                row_id_in_reg <= row_id_data_in;
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for r in 0 to ROWS-1 loop
                    row_data_reg(r) <= (others => '0');
                end loop;
            elsif load_w_reg = '1' then
                for r in 0 to ROWS-1 loop
                    row_data_reg(r) <= row_id_in_reg((r+1)*MAX_OUTPUT_ROWS_WIDTH-1 downto r*MAX_OUTPUT_ROWS_WIDTH);
                end loop;
            end if;
        end if;
    end process;


    gen_x_inject: for c in 0 to COLS-1 generate
        constant UPPER_BIT : integer := (c + 1) * group_size * INPUT_DATA_RADIX - 1;
        constant LOWER_BIT : integer := c * group_size * INPUT_DATA_RADIX;
    begin
        x_in(0, c) <= x_col_bits(UPPER_BIT downto LOWER_BIT);
    end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for r in 1 to ROWS-1 loop
                    for c in 0 to COLS-1 loop
                        x_up_delay(r, c)  <= (others => '0');
                        en_up_delay(r, c) <= '0';
                    end loop;
                end loop;
            else
                for r in 1 to ROWS-1 loop
                    for c in 0 to COLS-1 loop
                        x_up_delay(r, c)  <= x_out(r-1, c);
                        en_up_delay(r, c) <= en_next(r-1, c);
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    gen_x_up: for r in 1 to ROWS-1 generate
        gen_x_up_c: for c in 0 to COLS-1 generate
            x_in(r, c) <= x_up_delay(r, c);
        end generate;
    end generate;

    gen_en_skew: for c in 0 to COLS-1 generate
        no_delay: if c = 0 generate
            en_row0_skewed(c) <= en;
        end generate;

        with_delay: if c > 0 generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        en_delay_line(c) <= (others => '0');
                    else
                        en_delay_line(c) <= en_delay_line(c)(COLS-2 downto 0) & en;
                    end if;
                end if;
            end process;

            en_row0_skewed(c) <= en_delay_line(c)(c-1);
        end generate;
    end generate;

    gen_en_row0: for c in 0 to COLS-1 generate
        en_internal(0, c) <= en_row0_skewed(c) when rst = '0' else '0';
    end generate;

    gen_en_up: for r in 1 to ROWS-1 generate
        gen_en_up_c: for c in 0 to COLS-1 generate
            en_internal(r, c) <= en_up_delay(r, c);
        end generate;
    end generate;


    gen_w: for r in 0 to ROWS-1 generate
        gen_w_c: for c in 0 to COLS-1 generate
            constant id : integer := r*COLS + c;
        begin
            w_pe(r,c)   <= w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH);
            lut_pe(r,c) <= lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH);
        end generate;
    end generate;


    gen_psum_left: for r in 0 to ROWS-1 generate
        y_in(r, 0) <= (others => '0');
    end generate;

    gen_psum_lr: for r in 0 to ROWS-1 generate
        gen_psum_lr_c: for c in 1 to COLS-1 generate
            y_in(r, c) <= y_out(r, c-1);
        end generate;
    end generate;

    gen_pe_r: for r in 0 to ROWS-1 generate
        gen_pe_c: for c in 0 to COLS-1 generate
        begin
            PE_inst: entity work.PE
                generic map(
                    ROWS       => ROWS,
                    group_size => group_size,
                    NO_OF_MAC  => NO_OF_MAC,
                    DATA_WIDTH => DATA_WIDTH,
                    INPUT_DATA_RADIX => INPUT_DATA_RADIX
                )
                port map (
                    clk           => clk,
                    rst           => rst,
                    en            => en_internal(r,c),
                    load_w        => load_w_reg,
                    lut           => lut_pe(r, c),
                    w_in          => w_pe(r,c),
                    x_in          => x_in(r,c),
                    y_in          => y_in(r,c),
                    x_out         => x_out(r,c),
                    y_out         => y_out(r,c),
                    en_out        => en_next(r,c),
                    mac_valid_out => v_mat(r,c)
                );
        end generate;
    end generate;

    gen_raw: for r in 0 to ROWS-1 generate
        y_raw(r) <= y_out(r, COLS-1);
    end generate;

    gen_out_map: for r in 0 to ROWS-1 generate
    begin
        y_row_bits((r+1)*NO_OF_MAC*INPUT_DATA_RADIX - 1 downto r*NO_OF_MAC*INPUT_DATA_RADIX) <= y_raw(r);
        lane_valid_bits((r+1)*NO_OF_MAC - 1 downto r*NO_OF_MAC) <= v_mat(r, COLS-1);
        row_id_data_out((r+1)*MAX_OUTPUT_ROWS_WIDTH - 1 downto r*MAX_OUTPUT_ROWS_WIDTH) <= row_data_reg(r);
    end generate;

end architecture;