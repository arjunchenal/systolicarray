
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all; 

entity tb_controller is
end entity;

architecture tb of tb_controller is
    constant ADDR_WIDTH : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant ROWS       : integer := 4;
    constant COLS       : integer := 4;
    constant NO_OF_MAC  : integer := 4;
    constant OUT_WIDTH  : integer := 32;
    constant MAX_OUTPUT_ROWS_WIDTH : integer := 3;
    constant group_size : integer := 4;
    constant CLK_PERIOD : time    := 10 ns;

    constant INPUT_MATRIX_ROW : integer := 8;
    constant INPUT_MATRIX_COL : integer := 8;
    constant WEIGHT_MATRIX_ROW : integer := 8;
    constant WEIGHT_MATRIX_COL : integer := 8;

    constant MAX_ROW_ID_WIDTH : integer := 3;
    constant MAX_COL_GROUP_WIDTH : integer := 4;

    constant WEIGHT_BUS_WIDTH    : integer := ROWS * COLS * DATA_WIDTH;
    constant COL_GROUP_BUS_WIDTH : integer := COLS * group_size * MAX_COL_GROUP_WIDTH;
    constant ROW_ID_BUS_WIDTH    : integer := ROWS * MAX_ROW_ID_WIDTH;
    constant OUTPUT_BUS_WIDTH    : integer := ROWS * NO_OF_MAC * OUT_WIDTH;
    constant INPUT_BUS_WIDTH     : integer := ROWS * WEIGHT_MATRIX_COL * DATA_WIDTH;
    constant OUTPUT_SRAM_BUS_WIDTH    : integer := ROWS * COLS * OUT_WIDTH;

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

    signal start_signal : std_logic := '0';
    signal fsm_done     : std_logic := '0';
    signal fsm_rst_array: std_logic := '0';
    signal tb_sel : std_logic_vector(2 downto 0) := "000";
    signal tb_we  : std_logic := '0';
    signal tb_addr: std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal tb_din : std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0) := (others => '0');

    signal w_ram_we, lut_ram_we, input_ram_we, col_ram_we, row_ram_we : std_logic;
    signal ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal w_ram_din, w_ram_dout, lut_ram_din, lut_ram_dout : std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
    signal input_ram_din, input_ram_dout : std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);
    signal col_ram_din, col_ram_dout : std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);
    signal row_ram_din, row_ram_dout : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
    
    signal out_ram_we_fsm : std_logic;
    signal out_ram_addr_fsm : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal final_out_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal output_ram_dout : std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);
    
    signal final_rst : std_logic;

begin
    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    w_mat <= w_ram_dout; 
    lut_mat <= lut_ram_dout; 
    row_id_in <= row_ram_dout; 
    final_rst <= rst or fsm_rst_array;

    final_out_ram_addr <= tb_addr when fsm_done = '1' else out_ram_addr_fsm;

    main_ctrl: entity work.Controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => DATA_WIDTH,
            COLS => COLS, 
            group_size => group_size, 
            MAX_COL_GROUP_WIDTH => MAX_COL_GROUP_WIDTH,
            INPUT_BUS_WIDTH => INPUT_BUS_WIDTH, 
            OUTPUT_BUS_WIDTH => OUTPUT_BUS_WIDTH,
            ROW_ID_BUS_WIDTH => ROW_ID_BUS_WIDTH, 
            COL_GROUP_BUS_WIDTH => COL_GROUP_BUS_WIDTH,
            WEIGHT_BUS_WIDTH => WEIGHT_BUS_WIDTH--,
            --OUTPUT_SRAM_BUS_WIDTH => OUTPUT_SRAM_BUS_WIDTH
        )
        port map (
            clk => clk, 
            rst => rst, 
            start_signal => start_signal,
            tb_sel => tb_sel, 
            tb_we => tb_we, 
            tb_addr => tb_addr, 
            tb_din => tb_din,
            ram_addr => ram_addr, 
            w_ram_we => w_ram_we, 
            w_ram_din => w_ram_din,
            lut_ram_we => lut_ram_we, 
            lut_ram_din => lut_ram_din, 
            input_ram_we => input_ram_we, 
            input_ram_din => input_ram_din,
            col_ram_we => col_ram_we, 
            col_ram_din => col_ram_din, 
            row_ram_we => row_ram_we, 
            row_ram_din => row_ram_din,
            col_ram_dout => col_ram_dout, 
            input_ram_dout => input_ram_dout,
            out_ram_we => out_ram_we_fsm,
            out_ram_addr => out_ram_addr_fsm,
            en_sa => en_sa, 
            en_in => en_in, 
            load_w => load_w, 
            clear_buffer => clear_buffer, 
            rst_array => fsm_rst_array,
            data_in_row => data_in_row,
            data_valid_out => data_valid_out, 
            done => fsm_done
        );

    systolic_array: entity work.SystolicArray_serial
        generic map ( 
            DATA_WIDTH => DATA_WIDTH,  
            ROWS => ROWS, COLS => COLS, 
            group_size => group_size, 
            NO_OF_MAC => NO_OF_MAC, 
            MAX_OUTPUT_ROWS_WIDTH => MAX_OUTPUT_ROWS_WIDTH 
        )
        port map ( 
            clk=>clk, 
            rst=>final_rst, 
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
            rst=>final_rst, 
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
            rst=>final_rst, 
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
        ) port map(
            clk=>clk, 
            we=>w_ram_we, 
            re=>'1', 
            addr=>ram_addr, 
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
            addr=>ram_addr, 
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
            addr=>ram_addr, 
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
            addr=>ram_addr, 
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
            addr=>ram_addr, 
            din=>col_ram_din, 
            dout=>col_ram_dout
        );

    output_sram: entity work.sram 
        generic map(
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => OUTPUT_SRAM_BUS_WIDTH
        ) port map(
            clk=>clk, 
            we=>out_ram_we_fsm, 
            re=>'1', 
            addr=>final_out_ram_addr, 
            din=>y_parallel_out, 
            dout=>output_ram_dout
        );

    stim_proc: process
        file file_weights : text open read_mode is "weights.mem";
        file file_lut_index : text open read_mode is "lut_index.mem";
        file file_inputs  : text open read_mode is "inputs.mem";
        file file_col_group  : text open read_mode is "col_group.mem";
        file file_row_id  : text open read_mode is "row_id.mem";
        -- file file_output  : text open read_mode is "output.txt";

        variable current_line : line;
        variable weight_data  : std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        variable lut_index_data : std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        variable input_data   : std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);
        variable col_group_data    : std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);
        variable row_id_data    : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
        variable output_data  : std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);
        variable v_addr_id    : integer := 0;
    begin

        rst <= '1'; 
        wait for 20 ns; 
        rst <= '0'; 
        wait until rising_edge(clk);


        -- Weights
        tb_sel <= "000";
        v_addr_id := 0;
        while not endfile(file_weights) loop 
            readline(file_weights, current_line);
            hread(current_line, weight_data);
            tb_addr <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_din <= (others => '0');
            tb_din(WEIGHT_BUS_WIDTH-1 downto 0) <= weight_data;
            tb_we <= '1'; 
            wait until rising_edge(clk);
            tb_we <= '0'; 
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;

        -- LUT
        report "LUT Index";
        tb_sel <= "001";
        v_addr_id := 0;
        while not endfile(file_lut_index) loop
            readline(file_lut_index, current_line);
            hread(current_line, lut_index_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_din <= (others => '0');
            tb_din(WEIGHT_BUS_WIDTH-1 downto 0) <= lut_index_data;      
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk); 
            v_addr_id := v_addr_id + 1;
        end loop;


        -- Input
        report "Inputs";
        tb_sel <= "010";
        v_addr_id := 0;
        while not endfile(file_inputs) loop
            readline(file_inputs, current_line);
            hread(current_line, input_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_din <= (others => '0');
            tb_din(INPUT_BUS_WIDTH-1 downto 0) <= input_data;    
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;

        -- Col group
        report "Column group";
        tb_sel <= "011";
        v_addr_id := 0;
        while not endfile(file_col_group) loop
            readline(file_col_group, current_line);
            hread(current_line, col_group_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_din <= (others => '0');
            tb_din(COL_GROUP_BUS_WIDTH-1 downto 0) <= col_group_data;    
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;


        -- Row ID group
        report "Row id";
        tb_sel <= "100";
        v_addr_id := 0;
        while not endfile(file_row_id) loop
            readline(file_row_id, current_line);
            hread(current_line, row_id_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_din <= (others => '0');
            tb_din(ROW_ID_BUS_WIDTH-1 downto 0) <= row_id_data;    
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;

        start_signal <= '1'; 
        wait until rising_edge(clk); 
        start_signal <= '0';

        wait until fsm_done = '1';

        report "verify";
        for i in 0 to 3 loop
            tb_addr <= std_logic_vector(to_unsigned(i, ADDR_WIDTH));
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            
            report "" & integer'image(i) & "";
            
            for r in 0 to ROWS-1 loop
                report "  Sub-Row " & integer'image(r) & ": " & 
                    integer'image(to_integer(unsigned(output_ram_dout((r*NO_OF_MAC+0+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+0)*OUT_WIDTH)))) & ", " &
                    integer'image(to_integer(unsigned(output_ram_dout((r*NO_OF_MAC+1+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+1)*OUT_WIDTH)))) & ", " &
                    integer'image(to_integer(unsigned(output_ram_dout((r*NO_OF_MAC+2+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+2)*OUT_WIDTH)))) & ", " &
                    integer'image(to_integer(unsigned(output_ram_dout((r*NO_OF_MAC+3+1)*OUT_WIDTH-1 downto (r*NO_OF_MAC+3)*OUT_WIDTH))));
            end loop;
        end loop;

        sim_done <= true;
        wait;
    end process;
end architecture;

