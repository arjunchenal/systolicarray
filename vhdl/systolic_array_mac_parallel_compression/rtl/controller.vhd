
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Controller is
  generic (
    ADDR_WIDTH    : integer := 4;
    ROWS          : integer := 4;
    COLS          : integer := 4;
    DATA_WIDTH    : integer := 8;
    NO_OF_MAC     : integer := 1;
    GROUP_SIZE    : integer := 2;
    WEIGHT_ROWS   : integer := 8;
    WEIGHT_COLS   : integer := 4;
    IS_COMPRESSED : boolean := false;
    LATENCY       : integer := 4;
    OUT_WIDTH     : integer := 32;
    tb_width_output : integer := 512
  );
  port (
    clk, rst, start_signal : in  std_logic;

    tb_sel  : in  std_logic_vector(1 downto 0);
    tb_we   : in  std_logic;
    tb_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    tb_din  : in  std_logic_vector(tb_width_output-1 downto 0);
    tb_dout : out std_logic_vector(tb_width_output-1 downto 0);

    w_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    w_ram_din  : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    w_ram_we   : out std_logic;
    w_ram_dout : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);

    lut_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    lut_ram_din  : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    lut_ram_we   : out std_logic;
    lut_ram_dout : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);

    i_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    i_ram_din  : out std_logic_vector(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);
    i_ram_we   : out std_logic;
    i_ram_dout : in  std_logic_vector(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);

    o_ram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    o_ram_din  : out std_logic_vector(ROWS*COLS*OUT_WIDTH-1 downto 0);  
    o_ram_we   : out std_logic;
    o_ram_dout : in  std_logic_vector(ROWS*COLS*OUT_WIDTH-1 downto 0);

    sa_w_mat    : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    sa_lut_mat  : out std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    sa_x_data   : out std_logic_vector(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);

    sa_y_out    : in  std_logic_vector(ROWS*OUT_WIDTH-1 downto 0);  
    sa_y_valid  : out std_logic;

    sa_en       : out std_logic;
    sa_load_w   : out std_logic;
    sa_accum_en : out std_logic
  );
end entity;

architecture rtl of Controller is

  constant K_TILES        : integer := (WEIGHT_ROWS + ROWS - 1) / ROWS;
  constant N_TILES        : integer := (WEIGHT_COLS + COLS - 1) / COLS;
  constant W_RAM_WIDTH    : integer := ROWS*COLS*DATA_WIDTH;          
  constant TILES_PER_LINE : integer := (WEIGHT_ROWS + ROWS - 1)/ROWS; 
  constant W_LINE_WIDTH   : integer := TILES_PER_LINE * W_RAM_WIDTH;
  constant INPUT_ROWS_PER_TILE : integer := ROWS;
  constant FLUSH_CYCLES   : unsigned(2 downto 0) := "100";
  constant VALID_DELAY    : integer := ROWS + 1;

  type state_t is (IDLE, SETUP_TILE, SET_ADDR, LATCH_RAM, LOAD_WEIGHTS, PRE_STREAM,STREAM_INPUT, WAIT_DONE, NEXT_TILE);

  signal state_reg, next_state : state_t;
  signal tile_k_reg, next_tile_k : integer range 0 to K_TILES-1;
  signal tile_n_reg, next_tile_n : integer range 0 to N_TILES-1;

  signal ptr_x_reg, next_ptr_x : unsigned(ADDR_WIDTH-1 downto 0);
  signal flush_count_reg, next_flush_count : unsigned(2 downto 0);

  signal w_buffer_reg,   next_w_buffer   : std_logic_vector(W_RAM_WIDTH-1 downto 0);
  signal lut_buffer_reg, next_lut_buffer : std_logic_vector(W_RAM_WIDTH-1 downto 0);

  signal w_load_busy_reg,   next_w_load_busy   : std_logic;
  signal w_line_buffer_reg, next_w_line_buffer : std_logic_vector(W_LINE_WIDTH-1 downto 0);
  signal w_tile_phase_reg,  next_w_tile_phase  : integer range 0 to TILES_PER_LINE-1;
  signal w_base_addr_reg,   next_w_base_addr   : unsigned(ADDR_WIDTH-1 downto 0);

  signal valid_cnt_reg,    next_valid_cnt    : unsigned(7 downto 0);
  signal valid_active_reg, next_valid_active : std_logic;
  signal sa_y_valid_reg,   next_sa_y_valid   : std_logic;
  signal acc_reg, next_acc_reg : std_logic_vector(ROWS*COLS*OUT_WIDTH-1 downto 0);
  signal col_phase_reg, next_col_phase : integer range 0 to COLS-1;

  function build_weight_tile(line_buffer : std_logic_vector; tile_id : integer) return std_logic_vector is
    variable tile : std_logic_vector(W_RAM_WIDTH-1 downto 0);
    variable i, start_index, end_index : integer;
    constant TILE_DATA_SIZE : integer := OUT_WIDTH; -- 32
  begin
    for k in 0 to (W_RAM_WIDTH/TILE_DATA_SIZE)-1 loop
      i := (TILES_PER_LINE*k) + tile_id;
      start_index := k * TILE_DATA_SIZE;
      end_index   := i * TILE_DATA_SIZE;
      tile(start_index + TILE_DATA_SIZE - 1 downto start_index) :=
        line_buffer(end_index + TILE_DATA_SIZE - 1 downto end_index);
    end loop;
    return tile;
  end function;

  function place_col(tile_in : std_logic_vector; col_id : integer; col_vec : std_logic_vector) return std_logic_vector is
    variable t : std_logic_vector(tile_in'range);
    variable base : integer;
  begin
    t := tile_in;
    for r in 0 to ROWS-1 loop
      base := (r*COLS + col_id) * OUT_WIDTH;
      t(base + OUT_WIDTH - 1 downto base) := col_vec((r+1)*OUT_WIDTH - 1 downto r*OUT_WIDTH);
    end loop;
    return t;
  end function;

  function add_col(tile_in : std_logic_vector; col_id : integer; col_vec : std_logic_vector) return std_logic_vector is
    variable t : std_logic_vector(tile_in'range);
    variable base : integer;
    variable a, b, s : signed(OUT_WIDTH-1 downto 0);
  begin
    t := tile_in;
    for r in 0 to ROWS-1 loop
      base := (r*COLS + col_id) * OUT_WIDTH;
      a := signed(t(base + OUT_WIDTH - 1 downto base));
      b := signed(col_vec((r+1)*OUT_WIDTH - 1 downto r*OUT_WIDTH));
      s := a + b;
      t(base + OUT_WIDTH - 1 downto base) := std_logic_vector(s);
    end loop;
    return t;
  end function;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state_reg       <= IDLE;
        tile_k_reg      <= 0;
        tile_n_reg      <= 0;
        ptr_x_reg       <= (others => '0');
        flush_count_reg <= (others => '0');
        w_buffer_reg    <= (others => '0');
        lut_buffer_reg  <= (others => '0');
        w_load_busy_reg   <= '0';
        w_line_buffer_reg <= (others => '0');
        w_tile_phase_reg  <= 0;
        w_base_addr_reg   <= (others => '0');
        valid_cnt_reg     <= (others => '0');
        valid_active_reg  <= '0';
        sa_y_valid_reg    <= '0';
        acc_reg           <= (others => '0');
        col_phase_reg     <= 0;
      else
        state_reg       <= next_state;
        tile_k_reg      <= next_tile_k;
        tile_n_reg      <= next_tile_n;
        ptr_x_reg       <= next_ptr_x;
        flush_count_reg <= next_flush_count;
        w_buffer_reg    <= next_w_buffer;
        lut_buffer_reg  <= next_lut_buffer;
        w_load_busy_reg   <= next_w_load_busy;
        w_line_buffer_reg <= next_w_line_buffer;
        w_tile_phase_reg  <= next_w_tile_phase;
        w_base_addr_reg   <= next_w_base_addr;
        valid_cnt_reg     <= next_valid_cnt;
        valid_active_reg  <= next_valid_active;
        sa_y_valid_reg    <= next_sa_y_valid;
        acc_reg           <= next_acc_reg;
        col_phase_reg     <= next_col_phase;
      end if;
    end if;
  end process;

  process(all)
    variable ram_tile : integer;
    variable v_dense_word : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable capture_now : boolean;
  begin
    next_state       <= state_reg;
    next_tile_k      <= tile_k_reg;
    next_tile_n      <= tile_n_reg;
    next_ptr_x       <= ptr_x_reg;
    next_flush_count <= flush_count_reg;
    next_w_buffer    <= w_buffer_reg;
    next_lut_buffer  <= lut_buffer_reg;
    next_w_load_busy   <= w_load_busy_reg;
    next_w_line_buffer <= w_line_buffer_reg;
    next_w_tile_phase  <= w_tile_phase_reg;
    next_w_base_addr   <= w_base_addr_reg;
    next_valid_cnt     <= valid_cnt_reg;
    next_valid_active  <= valid_active_reg;
    next_sa_y_valid    <= '0';
    next_acc_reg       <= acc_reg;
    next_col_phase     <= col_phase_reg;
    tb_dout <= (others => '0');
    w_ram_we   <= '0'; 
    w_ram_addr   <= (others => '0'); 
    w_ram_din   <= (others => '0');
    lut_ram_we <= '0'; 
    lut_ram_addr <= (others => '0'); 
    lut_ram_din <= (others => '0');
    i_ram_we   <= '0'; 
    i_ram_addr   <= (others => '0'); 
    i_ram_din   <= (others => '0');
    o_ram_we   <= '0'; 
    o_ram_addr   <= (others => '0'); 
    o_ram_din   <= (others => '0');

    sa_en       <= '0';
    sa_load_w   <= '0';
    sa_accum_en <= '0';

    sa_w_mat   <= w_buffer_reg;
    sa_lut_mat <= lut_buffer_reg;
    sa_x_data  <= (others => '0');

    sa_y_valid <= sa_y_valid_reg;

    capture_now := (state_reg = IDLE) and (start_signal = '0') and (tb_sel = "00") and (tb_we = '1') and (w_load_busy_reg = '0');

    if capture_now then
      next_w_line_buffer <= tb_din(W_LINE_WIDTH-1 downto 0);
      next_w_base_addr   <= unsigned(tb_addr);
      next_w_tile_phase  <= 0;
      next_w_load_busy   <= '1';
    end if;

    if (w_load_busy_reg = '1') or capture_now then
      w_ram_we <= '1';

      if capture_now then
        w_ram_addr <= std_logic_vector(unsigned(tb_addr) + to_unsigned(0, ADDR_WIDTH));
        w_ram_din  <= build_weight_tile(tb_din(W_LINE_WIDTH-1 downto 0), 0);
      else
        w_ram_addr <= std_logic_vector(w_base_addr_reg + to_unsigned(w_tile_phase_reg, ADDR_WIDTH));
        w_ram_din  <= build_weight_tile(w_line_buffer_reg, w_tile_phase_reg);
      end if;

      if (w_load_busy_reg = '1') then
        if w_tile_phase_reg = TILES_PER_LINE-1 then
          next_w_load_busy  <= '0';
          next_w_tile_phase <= 0;
        else
          next_w_tile_phase <= w_tile_phase_reg + 1;
        end if;
      end if;
    end if;

    case state_reg is
      when IDLE =>
        next_tile_k  <= 0;
        next_tile_n  <= 0;
        next_ptr_x   <= (others => '0');
        next_col_phase <= 0;
        if start_signal = '1' then
          next_state <= SETUP_TILE;
        end if;

      when SETUP_TILE =>
        next_state <= SET_ADDR;
        next_acc_reg <= (others => '0');
        next_col_phase <= 0;

      when SET_ADDR =>
        next_state <= LATCH_RAM;

      when LATCH_RAM =>
        next_w_buffer   <= w_ram_dout;
        next_lut_buffer <= lut_ram_dout;
        next_ptr_x      <= (others => '0');
        next_state      <= LOAD_WEIGHTS;

      when LOAD_WEIGHTS =>
        next_state <= PRE_STREAM;

      when PRE_STREAM =>
        next_state  <= STREAM_INPUT;
        next_ptr_x  <= (others => '0');
        next_col_phase <= 0;

      when STREAM_INPUT =>
        if ptr_x_reg < to_unsigned(INPUT_ROWS_PER_TILE-1, ptr_x_reg'length) then
          next_ptr_x <= ptr_x_reg + 1;
        else
          next_flush_count  <= FLUSH_CYCLES;
          next_state        <= WAIT_DONE;
          next_valid_active <= '1';
          next_valid_cnt    <= (others => '0');
        end if;

      -- when WAIT_DONE =>
      
      --   if valid_active_reg = '1' then
      --     if to_integer(valid_cnt_reg) = VALID_DELAY - 1 then
      --       next_sa_y_valid   <= '1';
      --       next_valid_active <= '0';
      --     else
      --       next_valid_cnt <= valid_cnt_reg + 1;
      --     end if;
      --   end if;
      --   if next_sa_y_valid = '1' then
      --     if tile_k_reg = 0 then
      --       next_acc_reg <= place_col(acc_reg, col_phase_reg, sa_y_out);
      --     else
      --       next_acc_reg <= add_col(acc_reg, col_phase_reg, sa_y_out);
      --     end if;

      --     -- advance column phase
      --     if col_phase_reg = COLS-1 then
      --       next_col_phase <= 0;
      --       next_state <= NEXT_TILE;
      --     else
      --       next_col_phase <= col_phase_reg + 1;
      --       -- stay on same tile_k/tile_n, request another valid for next column
      --       next_state <= WAIT_DONE;
      --       next_valid_active <= '1';
      --       next_valid_cnt    <= (others => '0');
      --       next_flush_count  <= FLUSH_CYCLES;
      --     end if;

      --   elsif flush_count_reg = 0 then
      --     next_state <= WAIT_DONE; -- keep waiting (sa_y_valid is the real trigger)
      --   else
      --     next_flush_count <= flush_count_reg - 1;
      --   end if;





      when WAIT_DONE =>
        if valid_active_reg = '1' then

          if to_integer(valid_cnt_reg) >= (VALID_DELAY - 1) then
             next_sa_y_valid <= '1'; 
             if tile_k_reg = 0 then
                next_acc_reg <= place_col(acc_reg, col_phase_reg, sa_y_out);
             else
                next_acc_reg <= add_col(acc_reg, col_phase_reg, sa_y_out);
             end if;
             if col_phase_reg = COLS - 1 then
                next_col_phase    <= 0;
                next_valid_active <= '0';
                next_valid_cnt    <= (others => '0');
                next_state        <= NEXT_TILE;
             else
                next_col_phase    <= col_phase_reg + 1;
             end if;
          else
             next_valid_cnt <= valid_cnt_reg + 1;
          end if;

        elsif flush_count_reg /= 0 then
           next_flush_count <= flush_count_reg - 1;
        else
           next_state <= NEXT_TILE;
        end if;

      when NEXT_TILE =>
        if tile_k_reg < K_TILES-1 then
          next_tile_k <= tile_k_reg + 1;
          next_state  <= SET_ADDR;
        elsif tile_n_reg < N_TILES-1 then
          next_tile_n <= tile_n_reg + 1;
          next_tile_k <= 0;
          next_state  <= SETUP_TILE;
        else
          next_state <= IDLE;
        end if;

      when others =>
        next_state <= IDLE;
    end case;

    if state_reg /= IDLE then
      ram_tile := tile_k_reg * N_TILES + tile_n_reg;

      w_ram_addr   <= std_logic_vector(to_unsigned(ram_tile, ADDR_WIDTH));
      lut_ram_addr <= std_logic_vector(to_unsigned(ram_tile, ADDR_WIDTH));
      i_ram_addr   <= std_logic_vector(ptr_x_reg);

      if state_reg = LOAD_WEIGHTS then
        sa_load_w   <= '1';
        sa_en       <= '0';
        sa_accum_en <= '1';
      end if;

      if state_reg = PRE_STREAM then
        sa_en <= '0';
        if tile_k_reg = 0 then
          sa_accum_en <= '0';
        else
          sa_accum_en <= '1';
        end if;
      end if;

      if state_reg = STREAM_INPUT then
        sa_en       <= '1';
        sa_accum_en <= '1';
        i_ram_addr  <= std_logic_vector(ptr_x_reg + 1);

        if IS_COMPRESSED then
          sa_x_data <= i_ram_dout;
        else
          for c in 0 to COLS-1 loop
            if tile_k_reg = 0 then
              v_dense_word := i_ram_dout((c+1)*DATA_WIDTH-1 downto c*DATA_WIDTH);
            else
              v_dense_word := i_ram_dout((c+COLS+1)*DATA_WIDTH-1 downto (c+COLS)*DATA_WIDTH);
            end if;

            sa_x_data((GROUP_SIZE*c+1)*DATA_WIDTH-1 downto (GROUP_SIZE*c)*DATA_WIDTH) <= v_dense_word;
            sa_x_data((GROUP_SIZE*c+GROUP_SIZE)*DATA_WIDTH-1 downto (GROUP_SIZE*c+1)*DATA_WIDTH) <= (others => '0');
          end loop;
        end if;
      end if;

      if state_reg = WAIT_DONE then
        sa_en       <= '1';
        sa_accum_en <= '1';
      end if;

      if (state_reg = WAIT_DONE) and (next_sa_y_valid = '1') and (col_phase_reg = COLS-1) and (tile_k_reg = K_TILES-1) then
        o_ram_we   <= '1';
        o_ram_addr <= std_logic_vector(to_unsigned(tile_n_reg, ADDR_WIDTH));
        o_ram_din  <= next_acc_reg;
      end if;

    else

      if (start_signal = '0') and (not capture_now) then
        case tb_sel is
          when "00" =>
            w_ram_addr <= tb_addr;
            tb_dout(W_RAM_WIDTH-1 downto 0) <= w_ram_dout;

          when "11" =>
            lut_ram_we   <= tb_we;
            lut_ram_addr <= tb_addr;
            lut_ram_din  <= tb_din(W_RAM_WIDTH-1 downto 0);
            tb_dout(W_RAM_WIDTH-1 downto 0) <= lut_ram_dout;

          when "01" =>
            i_ram_we   <= tb_we;
            i_ram_addr <= tb_addr;
            i_ram_din  <= tb_din(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0);
            tb_dout(COLS*GROUP_SIZE*DATA_WIDTH-1 downto 0) <= i_ram_dout;

          when "10" =>
            o_ram_addr <= tb_addr;
            tb_dout(ROWS*COLS*OUT_WIDTH-1 downto 0) <= o_ram_dout;

          when others =>
            null;
        end case;
      end if;
    end if;

  end process;

end architecture;
