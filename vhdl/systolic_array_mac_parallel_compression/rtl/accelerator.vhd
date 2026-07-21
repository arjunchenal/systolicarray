library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Accelerator is
  generic (
    ROWS       : integer := 4;
    COLS       : integer := 4;
    ADDR_WIDTH : integer := 4;

    DATA_WIDTH : integer := 8;
    OUT_WIDTH  : integer := 32;
    GROUP_SIZE : integer := 2;

    input_matrix_row  : integer := 4;
    input_matrix_col  : integer := 8;
    weight_matrix_row : integer := 8;
    weight_matrix_col : integer := 4;
    tb_width_output : integer := 1;
    IS_COMPRESSED : boolean := true
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    start_signal : in  std_logic;

    tb_sel  : in  std_logic_vector(1 downto 0);
    tb_we   : in  std_logic;
    tb_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);

    tb_din  : in  std_logic_vector(tb_width_output-1 downto 0);
    tb_dout : out std_logic_vector(tb_width_output-1 downto 0);

    -- Weight SRAM
    w_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    w_ram_din  : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    w_ram_we   : out std_logic;
    w_ram_dout : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);

    -- LUT SRAM
    lut_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    lut_ram_din  : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    lut_ram_we   : out std_logic;
    lut_ram_dout : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);

    -- Input SRAM 
    i_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    i_ram_din  : out std_logic_vector(input_matrix_col*DATA_WIDTH-1 downto 0);
    i_ram_we   : out std_logic;
    i_ram_dout : in  std_logic_vector(input_matrix_col*DATA_WIDTH-1 downto 0);

    -- Output SRAM
    o_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    o_ram_din  : out std_logic_vector(ROWS*COLS*OUT_WIDTH-1 downto 0);
    o_ram_we   : out std_logic;
    o_ram_dout : in  std_logic_vector(ROWS*COLS*OUT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of Accelerator is

  signal sa_w_mat  : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
  signal sa_lut_mat : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
  signal sa_x_data : std_logic_vector(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);

  signal sa_y_raw     : std_logic_vector(ROWS*OUT_WIDTH-1 downto 0);
  signal sa_y_aligned : std_logic_vector(ROWS*OUT_WIDTH-1 downto 0);

  signal x_skewed_bus : std_logic_vector(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);

  signal sa_en_s       : std_logic;
  signal sa_load_w_s   : std_logic;
  signal sa_accum_en_s : std_logic;
  signal sa_y_valid_s  : std_logic;

begin

  u_ctrl: entity work.Controller
    generic map (
      ADDR_WIDTH   => ADDR_WIDTH,
      ROWS         => ROWS,
      COLS         => COLS,
      DATA_WIDTH   => DATA_WIDTH,
      NO_OF_MAC    => 1,
      GROUP_SIZE   => GROUP_SIZE,
      WEIGHT_ROWS  => weight_matrix_row,
      WEIGHT_COLS  => weight_matrix_col,
      OUT_WIDTH    => OUT_WIDTH,
      tb_width_output => tb_width_output,
      IS_COMPRESSED => IS_COMPRESSED
    )
    port map (
      clk          => clk,
      rst          => rst,
      start_signal => start_signal,

      tb_sel       => tb_sel,
      tb_we        => tb_we,
      tb_addr      => tb_addr,
      tb_din       => tb_din,
      tb_dout      => tb_dout,
      w_ram_addr   => w_ram_addr,
      w_ram_din    => w_ram_din,
      w_ram_we     => w_ram_we,
      w_ram_dout   => w_ram_dout,
      lut_ram_addr   => lut_ram_addr,
      lut_ram_din    => lut_ram_din,
      lut_ram_we     => lut_ram_we,
      lut_ram_dout   => lut_ram_dout,
      i_ram_addr   => i_ram_addr,
      i_ram_din    => i_ram_din,
      i_ram_we     => i_ram_we,
      i_ram_dout   => i_ram_dout,
      o_ram_addr   => o_ram_addr,
      o_ram_din    => o_ram_din,
      o_ram_we     => o_ram_we,
      o_ram_dout   => o_ram_dout,
      sa_w_mat     => sa_w_mat,
      sa_lut_mat   => sa_lut_mat,
      sa_x_data    => sa_x_data,
      sa_y_out     => sa_y_aligned, --sa_y_raw,
      sa_y_valid   => sa_y_valid_s,
      sa_en        => sa_en_s,
      sa_load_w    => sa_load_w_s,
      sa_accum_en  => sa_accum_en_s
    );

  u_inbuf: entity work.InputRegisterArray
    generic map (
      COLS       => COLS,
      DATA_WIDTH => DATA_WIDTH,
      group_size => GROUP_SIZE,
      OUT_WIDTH => OUT_WIDTH
    )
    port map (
      clk          => clk,
      rst          => rst,
      en => '1',
      data_in_row  => sa_x_data,  
      data_to_cols => x_skewed_bus
    );

  u_array: entity work.SystolicArray
    generic map (
      ROWS => ROWS,
      COLS => COLS,
      group_size => GROUP_SIZE,
      ADDR_WIDTH => ADDR_WIDTH,
      OUT_WIDTH => OUT_WIDTH
    )
    port map (
      clk          => clk,
      rst          => rst,
      load_weight  => sa_load_w_s,   
      x_bottom_bus => x_skewed_bus,
      w_mat        => sa_w_mat,
      lut_mat      => sa_lut_mat,
      y_out_bus    => sa_y_raw
    );

  u_outbuf: entity work.Output_Buffer
    generic map (
      ROWS       => ROWS,
      DATA_WIDTH => OUT_WIDTH
    )
    port map (
      clk      => clk,
      rst      => rst,
      data_in  => sa_y_raw,
      data_out => sa_y_aligned
    );

end architecture;
