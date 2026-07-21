library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pe_sys_grid_4x4 is
end entity;

architecture tb of tb_pe_sys_grid_4x4 is
    constant ADDR_WIDTH : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant ROWS       : integer := 4;
    constant COLS       : integer := 4;
    constant NO_OF_MAC  : integer := 4;
    constant OUT_WIDTH  : integer := 32;
    constant MAX_OUTPUT_ROWS_WIDTH : integer := 3;
    constant group_size : integer := 4;

    constant INPUT_MATRIX_ROW : integer := 8;
    constant INPUT_MATRIX_COL : integer := 8;

    constant MAX_ROW_ID_WIDTH : integer := 3;
    constant MAX_COL_GROUP_WIDTH : integer := 4;

    constant WEIGHT_BUS_WIDTH    : integer := ROWS * COLS * DATA_WIDTH;
    constant COL_GROUP_BUS_WIDTH : integer := COLS * group_size * MAX_COL_GROUP_WIDTH;
    constant ROW_ID_BUS_WIDTH    : integer := ROWS * MAX_ROW_ID_WIDTH;
    constant OUTPUT_BUS_WIDTH    : integer := ROWS * NO_OF_MAC * OUT_WIDTH;
    constant INPUT_BUS_WIDTH     : integer := INPUT_MATRIX_COL * DATA_WIDTH;

    signal clk, rst, load_w, en_sa, en_in : std_logic := '0';
    signal x_col_bits      : std_logic_vector((COLS*group_size)-1 downto 0);
    
    signal w_mat, lut_mat  : std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
    signal y_row_bits      : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);
    signal data_in_row     : std_logic_vector((COLS*group_size*DATA_WIDTH-1) downto 0);
    signal y_parallel_out  : std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);
    
    signal row_id_in       : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0) := (others => '0');
    signal row_id_out      : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
    
    signal clear_buffer    : std_logic := '0';
    signal data_valid_out  : std_logic;
    signal sim_done        : boolean := false; 

    signal w_ram_we, lut_ram_we, input_ram_we : std_logic := '0';
    signal w_ram_addr, lut_ram_addr, input_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal w_ram_din, w_ram_dout, lut_ram_din, lut_ram_dout : std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0) := (others => '0');

    signal input_ram_din, input_ram_dout : std_logic_vector(INPUT_BUS_WIDTH-1 downto 0) := (others=>'0');

    signal col_ram_we, row_ram_we : std_logic := '0';
    signal col_ram_addr, row_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal col_ram_din, col_ram_dout : std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0) := (others => '0');
    signal row_ram_din, row_ram_dout : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0) := (others => '0');

begin
    clk_gen: process
    begin
        while not sim_done loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
        wait;
    end process;

    w_mat <= w_ram_dout;
    lut_mat <= lut_ram_dout;
    row_id_in <= row_ram_dout; 

    systolic_array: entity work.SystolicArray_serial
        generic map ( 
            DATA_WIDTH => DATA_WIDTH,  
            ROWS => ROWS, 
            COLS => COLS, 
            group_size => group_size, 
            NO_OF_MAC => NO_OF_MAC, 
            MAX_OUTPUT_ROWS_WIDTH => MAX_OUTPUT_ROWS_WIDTH
        )
        port map ( 
            clk=>clk, 
            rst=>rst, 
            en=>en_sa, 
            load_w=>load_w, 
            x_col_bits=>x_col_bits, 
            w_mat=>w_mat, 
            lut_mat=>lut_mat,  
            y_row_bits=>y_row_bits, 
            lane_valid_bits=>open,                
            row_id_data_in=>row_id_in, 
            row_id_data_out=>row_id_out 
        );

    input_reg: entity work.InputRegisterArray
        generic map(
            COLS => COLS, 
            DATA_WIDTH => DATA_WIDTH, 
            group_size => group_size
        )
        port map(
            clk=>clk, 
            rst=>rst, 
            en=>en_in, 
            clear_pipeline => clear_buffer, 
            data_in_row=>data_in_row, 
            data_to_cols=>x_col_bits
        );

    output_buffer: entity work.OutputBuffer
        generic map (
            ROWS => ROWS, 
            COLS => COLS, 
            NO_OF_MAC => NO_OF_MAC, 
            OUT_WIDTH => OUT_WIDTH, 
            MAX_OUTPUT_ROWS_WIDTH => MAX_OUTPUT_ROWS_WIDTH
        )
        port map (
            clk=>clk, 
            rst=>rst, 
            array_en=>en_sa, 
            y_serial_in=>y_row_bits, 
            row_ids_in=>row_id_out, 
            clear_buffer=>clear_buffer,
            y_parallel_out=>y_parallel_out, 
            data_valid_out=>data_valid_out
        );

    weight_sram: entity work.sram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => WEIGHT_BUS_WIDTH
        )
        port map(
            clk=>clk, 
            we=>w_ram_we, 
            re=>'1', 
            addr=>w_ram_addr, 
            din=>w_ram_din, 
            dout=>w_ram_dout
        );

    lut_sram: entity work.sram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => WEIGHT_BUS_WIDTH
        )
        port map(
            clk=>clk, 
            we=>lut_ram_we, 
            re=>'1', 
            addr=>lut_ram_addr, 
            din=>lut_ram_din, 
            dout=>lut_ram_dout
        );

    input_sram: entity work.sram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => INPUT_BUS_WIDTH
        )
        port map(
            clk=>clk, 
            we=>input_ram_we, 
            re=>'1', 
            addr=>input_ram_addr, 
            din=>input_ram_din, 
            dout=>input_ram_dout
        );

    row_id_sram: entity work.sram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => ROW_ID_BUS_WIDTH
        )
        port map(
            clk=>clk, 
            we=>row_ram_we, 
            re=>'1', 
            addr=>row_ram_addr, 
            din=>row_ram_din, 
            dout=>row_ram_dout
        );

    col_group_sram: entity work.sram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => COL_GROUP_BUS_WIDTH
        )
        port map(
            clk=>clk, 
            we=>col_ram_we, 
            re=>'1', 
            addr=>col_ram_addr, 
            din=>col_ram_din, 
            dout=>col_ram_dout
        );


    stim_proc: process
        type lane_indices is array (0 to group_size-1) of integer;
        type col_map_array is array (0 to COLS-1) of lane_indices;
        variable col_map : col_map_array;
        
        variable target_id, bit_offset : integer;
        
        type final_mat_t is array (0 to INPUT_MATRIX_ROW-1, 0 to INPUT_MATRIX_COL-1) of integer; 
        variable final_mat : final_mat_t := (others => (others => 0));

        type tile_map_t is array (0 to ROWS-1) of integer;
        variable tile0_log_rows : tile_map_t := (6, 3, 4, 2);
        variable tile1_log_rows : tile_map_t := (1, 0, 7, 5);
        variable log_r : integer;

    begin

        wait until rising_edge(clk);
        w_ram_we <= '1'; 
        lut_ram_we <= '1'; 
        input_ram_we <= '1'; 
        row_ram_we <= '1'; 
        col_ram_we <= '1';
        
        w_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        lut_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        row_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        col_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        
        w_ram_din   <= x"05010904_07010204_04050005_09030306";
        lut_ram_din <= x"00000000_00010000_00000001_01000001";
        row_ram_din <= x"688"; 
        col_ram_din <= x"FF65FF30FFF2FF74"; 
        
        input_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        input_ram_din <= x"50463C32281E140A"; 
        wait until rising_edge(clk);

        w_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        lut_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        row_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        col_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        
        w_ram_din   <= x"00040003_00030002_00040706_00060802";
        lut_ram_din <= x"00000003_00000002_00010001_00000000";
        row_ram_din <= x"688"; 
        col_ram_din <= x"FFFFFF21FFF76540"; 
        wait until rising_edge(clk);

        w_ram_we <= '0'; 
        lut_ram_we <= '0'; 
        input_ram_we <= '0';
        row_ram_we <= '0'; 
        col_ram_we <= '0';
        wait until rising_edge(clk);

        rst <= '1'; 
        wait for 20 ns; 
        rst <= '0'; 
        wait until rising_edge(clk);

        w_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        lut_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        row_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        col_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        input_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        
        wait until rising_edge(clk); 
        wait until rising_edge(clk);

        for c in 0 to COLS-1 loop
            for lane in 0 to group_size-1 loop
                col_map(c)(lane) := to_integer(signed(col_ram_dout((c*group_size + lane)*MAX_COL_GROUP_WIDTH + (MAX_COL_GROUP_WIDTH-1) downto (c*group_size + lane)*MAX_COL_GROUP_WIDTH)));
            end loop;
        end loop;
        
        load_w <= '1'; 
        wait until rising_edge(clk); 
        load_w <= '0';
        en_sa <= '1';
        en_in <= '1';


        for i in 0 to (COLS * DATA_WIDTH) - 1 loop
            data_in_row <= (others => '0');
            if (i mod DATA_WIDTH = 0) and (i <= (COLS-1)*DATA_WIDTH) then
                for c in 0 to COLS-1 loop
                    for lane in 0 to group_size-1 loop
                        target_id := col_map(c)(lane); 
                        bit_offset := (c * group_size + lane) * DATA_WIDTH;
                        if target_id /= -1 then
                            data_in_row(bit_offset + DATA_WIDTH-1 downto bit_offset) <= input_ram_dout(target_id * DATA_WIDTH + DATA_WIDTH-1 downto target_id * DATA_WIDTH);
                        end if;
                    end loop;
                end loop;
            end if;
            wait until rising_edge(clk);
        end loop;

        wait until data_valid_out = '1';
        
        for r in 0 to ROWS-1 loop
            log_r := tile0_log_rows(r);
            for m in 0 to NO_OF_MAC-1 loop
                final_mat(log_r, m) := to_integer(unsigned(y_parallel_out((r*NO_OF_MAC+m+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+m)*OUT_WIDTH)));
            end loop;
        end loop;

        clear_buffer <= '1'; 
        wait until rising_edge(clk); 
        clear_buffer <= '0';


        for i in 0 to (COLS * DATA_WIDTH) - 1 loop
            data_in_row <= (others => '0');
            if (i mod DATA_WIDTH = 0) and (i <= (COLS-1)*DATA_WIDTH) then
                for c in 0 to COLS-1 loop
                    for lane in 0 to group_size-1 loop
                        target_id := col_map(c)(lane);
                        bit_offset := (c * group_size + lane) * DATA_WIDTH;
                        if target_id /= -1 then
                            data_in_row(bit_offset + DATA_WIDTH-1 downto bit_offset) <= input_ram_dout(target_id * DATA_WIDTH + DATA_WIDTH-1 downto target_id * DATA_WIDTH);
                        end if;
                    end loop;
                end loop;
            end if;
            wait until rising_edge(clk);
        end loop;

        wait until data_valid_out = '1';
        
        for r in 0 to ROWS-1 loop
            log_r := tile0_log_rows(r);
            for m in 0 to NO_OF_MAC-1 loop
                final_mat(log_r, m + NO_OF_MAC) := to_integer(unsigned(y_parallel_out((r*NO_OF_MAC+m+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+m)*OUT_WIDTH)));
            end loop;
        end loop;


        en_sa <= '0'; 
        en_in <= '0'; 
        wait until rising_edge(clk);
        rst <= '1'; 
        clear_buffer <= '1';
        wait until rising_edge(clk); 
        wait until rising_edge(clk);
        rst <= '0'; 
        clear_buffer <= '0'; 
        wait until rising_edge(clk);


        w_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        lut_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        row_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        col_ram_addr <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        
        wait until rising_edge(clk); 
        wait until rising_edge(clk);

        for c in 0 to COLS-1 loop
            for lane in 0 to group_size-1 loop
                col_map(c)(lane) := to_integer(signed(col_ram_dout((c*group_size + lane)*MAX_COL_GROUP_WIDTH + (MAX_COL_GROUP_WIDTH-1) downto (c*group_size + lane)*MAX_COL_GROUP_WIDTH)));
            end loop;
        end loop;
        
        load_w <= '1'; 
        wait until rising_edge(clk); 
        load_w <= '0';
        en_sa <= '1'; 
        en_in <= '1';


        for i in 0 to (COLS * DATA_WIDTH) - 1 loop
            data_in_row <= (others => '0');
            if (i mod DATA_WIDTH = 0) and (i <= (COLS-1)*DATA_WIDTH) then
                for c in 0 to COLS-1 loop
                    for lane in 0 to group_size-1 loop
                        target_id := col_map(c)(lane); 
                        bit_offset := (c * group_size + lane) * DATA_WIDTH;
                        if target_id /= -1 then
                            data_in_row(bit_offset + DATA_WIDTH-1 downto bit_offset) <= input_ram_dout(target_id * DATA_WIDTH + DATA_WIDTH-1 downto target_id * DATA_WIDTH);
                        end if;
                    end loop;
                end loop;
            end if;
            wait until rising_edge(clk);
        end loop;

        wait until data_valid_out = '1';
        for r in 0 to ROWS-1 loop
            log_r := tile1_log_rows(r);
            for m in 0 to NO_OF_MAC-1 loop
                final_mat(log_r, m) := to_integer(unsigned(y_parallel_out((r*NO_OF_MAC+m+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+m)*OUT_WIDTH)));
            end loop;
        end loop;

        clear_buffer <= '1'; 
        wait until rising_edge(clk); 
        clear_buffer <= '0';

        for i in 0 to (COLS * DATA_WIDTH) - 1 loop
            data_in_row <= (others => '0');
            if (i mod DATA_WIDTH = 0) and (i <= (COLS-1)*DATA_WIDTH) then
                for c in 0 to COLS-1 loop
                    for lane in 0 to group_size-1 loop
                        target_id := col_map(c)(lane);
                        bit_offset := (c * group_size + lane) * DATA_WIDTH;
                        if target_id /= -1 then
                            data_in_row(bit_offset + DATA_WIDTH-1 downto bit_offset) <= input_ram_dout(target_id * DATA_WIDTH + DATA_WIDTH-1 downto target_id * DATA_WIDTH);
                        end if;
                    end loop;
                end loop;
            end if;
            wait until rising_edge(clk);
        end loop;

        wait until data_valid_out = '1';
        for r in 0 to ROWS-1 loop
            log_r := tile1_log_rows(r);
            for m in 0 to NO_OF_MAC-1 loop
                final_mat(log_r, m + NO_OF_MAC) := to_integer(unsigned(y_parallel_out((r*NO_OF_MAC+m+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+m)*OUT_WIDTH)));
            end loop;
        end loop;
        
        clear_buffer <= '1'; 
        wait until rising_edge(clk); 
        clear_buffer <= '0';

        report "verify";
        for r in 0 to INPUT_MATRIX_ROW-1 loop
            report "ROW " & integer'image(r) & ": " &
                integer'image(final_mat(r, 0)) & ", " & integer'image(final_mat(r, 1)) & ", " &
                integer'image(final_mat(r, 2)) & ", " & integer'image(final_mat(r, 3)) & ", " &
                integer'image(final_mat(r, 4)) & ", " & integer'image(final_mat(r, 5)) & ", " &
                integer'image(final_mat(r, 6)) & ", " & integer'image(final_mat(r, 7));
        end loop;

        en_sa <= '0'; 
        en_in <= '0'; 
        sim_done <= true;
        wait;
    end process;

end architecture;