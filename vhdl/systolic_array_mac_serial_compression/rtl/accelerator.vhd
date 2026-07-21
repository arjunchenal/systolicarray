library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Accelerator is
    generic (
        ADDR_WIDTH : integer := 4;
        DATA_WIDTH : integer := 8;
        OUT_WIDTH : integer := 32;
        group_size : integer := 4;
        NO_OF_MAC : integer := 4;
        ROWS : integer := 4;
        COLS : integer := 4;
        MAX_OUTPUT_ROWS_WIDTH : integer := 3;
        MAX_COL_GROUP_WIDTH : integer := 4;
        INPUT_BUS_WIDTH     : integer := 256;
        OUTPUT_BUS_WIDTH    : integer := 512;
        ROW_ID_BUS_WIDTH    : integer := 12;
        COL_GROUP_BUS_WIDTH : integer := 64;
        WEIGHT_BUS_WIDTH    : integer := 128;
        OUTPUT_SRAM_BUS_WIDTH : integer := 128
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        start_signal : in std_logic;

        tb_sel  : in std_logic_vector(2 downto 0);
        tb_we   : in std_logic;
        tb_addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        tb_din  : in std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);
        tb_dout : out std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);

        ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);

        w_ram_we   : out std_logic;
        w_ram_din  : out std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        w_ram_dout : in  std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);

        lut_ram_we   : out std_logic;
        lut_ram_din  : out std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        lut_ram_dout : in  std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);

        input_ram_we   : out std_logic;
        input_ram_din  : out std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);
        input_ram_dout : in  std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);

        col_ram_we   : out std_logic;
        col_ram_din  : out std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);
        col_ram_dout : in  std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);

        row_ram_we   : out std_logic;
        row_ram_din  : out std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
        row_ram_dout : in  std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);

        output_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        output_ram_we : out std_logic;
        output_ram_din : out std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);
        output_ram_dout : in std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);

        fsm_done       : out std_logic
    );
end entity Accelerator;

architecture rtl of Accelerator is
    signal en_sa, en_in, load_w, clear_buffer, rst_array : std_logic;
    signal data_in_row : std_logic_vector((COLS*group_size*DATA_WIDTH-1) downto 0);
    signal x_col_bits  : std_logic_vector((COLS*group_size)-1 downto 0);
    signal final_rst   : std_logic;
    signal y_row_bits  : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);

    signal w_mat         : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal lut_mat       : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    
    signal data_valid_out : std_logic;


    signal row_id_in       : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
    signal row_id_out      : std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);

    signal y_parallel_out  : std_logic_vector(ROWS*NO_OF_MAC*OUT_WIDTH-1 downto 0);

    signal final_out_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal out_ram_addr_fsm : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal fsm_rst_array: std_logic := '0';
begin

    final_rst <= rst or fsm_rst_array;


    controller: entity work.Controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => DATA_WIDTH,
            ROWS => ROWS,
            COLS => COLS, 
            NO_OF_MAC => NO_OF_MAC,
            OUT_WIDTH => OUT_WIDTH,
            group_size => group_size, 
            MAX_COL_GROUP_WIDTH => MAX_COL_GROUP_WIDTH,
            INPUT_BUS_WIDTH => INPUT_BUS_WIDTH,
            OUTPUT_BUS_WIDTH => OUTPUT_BUS_WIDTH,
            ROW_ID_BUS_WIDTH => ROW_ID_BUS_WIDTH, 
            COL_GROUP_BUS_WIDTH => COL_GROUP_BUS_WIDTH,
            WEIGHT_BUS_WIDTH => WEIGHT_BUS_WIDTH
        )
        port map (
            clk => clk, 
            rst => rst, 
            start_signal => start_signal,
            tb_sel => tb_sel, 
            tb_we => tb_we, 
            tb_addr => tb_addr, 
            tb_din => tb_din,
            tb_dout => tb_dout,
            w_mat => w_mat,
            lut_mat => lut_mat,
            ram_addr => ram_addr, 
            w_ram_we => w_ram_we, 
            w_ram_din => w_ram_din,
            w_ram_dout => w_ram_dout,
            lut_ram_we => lut_ram_we, 
            lut_ram_din => lut_ram_din, 
            lut_ram_dout => lut_ram_dout,
            input_ram_we => input_ram_we, 
            input_ram_din => input_ram_din,
            input_ram_dout => input_ram_dout,
            col_ram_we => col_ram_we, 
            col_ram_din => col_ram_din, 
            col_ram_dout => col_ram_dout,
            row_ram_we => row_ram_we, 
            row_ram_din => row_ram_din,
            row_ram_dout => row_ram_dout,

            output_ram_addr => output_ram_addr,
            output_ram_we => output_ram_we,
            output_ram_din => output_ram_din,
            output_ram_dout => output_ram_dout,

            en_sa => en_sa, 
            en_in => en_in, 
            load_w => load_w, 
            clear_buffer => clear_buffer, 
            rst_array => fsm_rst_array,
            data_in_row => data_in_row, 
            data_valid_out => data_valid_out,
            done => fsm_done,
            sa_y_out => y_parallel_out
        );

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
            rst=>final_rst, 
            en=>en_sa, 
            load_w=>load_w, 
            x_col_bits=>x_col_bits, 
            w_mat=>w_mat, 
            lut_mat=>lut_mat, 
            y_row_bits=>y_row_bits, 
            lane_valid_bits=>open, 
            row_id_data_in=>row_ram_din,
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
    
end architecture;