
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Controller is
    generic (
        ADDR_WIDTH : integer := 4;
        DATA_WIDTH : integer := 8;
        COLS       : integer := 4;
        ROWS       : integer := 4;
        group_size : integer := 4;
        NO_OF_MAC : integer := 4;
        OUT_WIDTH : integer := 32;
        MAX_COL_GROUP_WIDTH : integer := 4;
        INPUT_BUS_WIDTH     : integer := 256;
        OUTPUT_BUS_WIDTH    : integer := 512;
        ROW_ID_BUS_WIDTH    : integer := 12;
        COL_GROUP_BUS_WIDTH : integer := 64;
        WEIGHT_BUS_WIDTH    : integer := 128;
        OUTPUT_SRAM_BUS_WIDTH : integer := 512;
        MAX_OUTPUT_ROWS_WIDTH : integer := 3
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
    
        ram_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        w_ram_we      : out std_logic;
        w_ram_din     : out std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        w_ram_dout    : in std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);

        lut_ram_we    : out std_logic;
        lut_ram_din   : out std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);
        lut_ram_dout  : in std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);

        input_ram_we  : out std_logic;
        input_ram_din : out std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);
        input_ram_dout : in std_logic_vector(INPUT_BUS_WIDTH-1 downto 0);

        col_ram_we    : out std_logic;
        col_ram_din   : out std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);
        col_ram_dout  : in std_logic_vector(COL_GROUP_BUS_WIDTH-1 downto 0);

        row_ram_we    : out std_logic;
        row_ram_din   : out std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);
        row_ram_dout : in std_logic_vector(ROW_ID_BUS_WIDTH-1 downto 0);

        output_ram_we    : out std_logic;
        output_ram_addr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        output_ram_din : out std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);
        output_ram_dout : in std_logic_vector(OUTPUT_SRAM_BUS_WIDTH-1 downto 0);

        en_sa, en_in : out std_logic;
        load_w, clear_buffer, rst_array : out std_logic;
        data_in_row  : out std_logic_vector((COLS*group_size*DATA_WIDTH)-1 downto 0);
        w_mat, lut_mat  : out std_logic_vector(WEIGHT_BUS_WIDTH-1 downto 0);


        sa_y_out : in std_Logic_vector(ROWS*NO_OF_MAC*OUT_WIDTH-1 downto 0);
        
        data_valid_out : in std_logic;
        done           : out std_logic
    );
end entity;

architecture rtl of Controller is
    type state_type is (S_IDLE, S_FETCH, S_WAIT_MEM, S_LOAD, S_EXECUTE, S_WAIT_OUT, S_TILE_SWAP, S_DONE);
    signal state, next_state : state_type;
    
    signal tile_cnt, next_tile_cnt   : unsigned(ADDR_WIDTH-1 downto 0);
    signal batch_cnt, next_batch_cnt : unsigned(0 downto 0);
    signal feed_cnt, next_feed_cnt   : integer range 0 to 127;

    type lane_indices_t is array (0 to group_size-1) of integer range -1 to 31;
    type col_map_array is array (0 to COLS-1) of lane_indices_t;
    signal col_map : col_map_array;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
                tile_cnt <= (others => '0');
                batch_cnt <= "0";
                feed_cnt <= 0;
            else
                state <= next_state;
                tile_cnt <= next_tile_cnt;
                batch_cnt <= next_batch_cnt;
                feed_cnt <= next_feed_cnt;
                
                if state = S_LOAD then
                    for c in 0 to COLS-1 loop
                        for lane in 0 to group_size-1 loop
                            col_map(c)(lane) <= to_integer(signed(col_ram_dout((c*group_size + lane)*MAX_COL_GROUP_WIDTH + (MAX_COL_GROUP_WIDTH-1) downto (c*group_size + lane)*MAX_COL_GROUP_WIDTH)));
                        end loop;
                    end loop;
                end if;
            end if;
        end if;
    end process;

    -- process(state, start_signal, feed_cnt, batch_cnt, tile_cnt, data_valid_out)
    process(all)
    begin
        next_state <= state;
        next_tile_cnt <= tile_cnt;
        next_batch_cnt <= batch_cnt;
        next_feed_cnt <= feed_cnt;

        case state is
            when S_IDLE =>
                if start_signal = '1' then
                    next_state <= S_FETCH;
                    next_tile_cnt <= (others => '0');
                    next_batch_cnt <= "0";
                end if;
            when S_FETCH =>
                next_state <= S_WAIT_MEM;
            when S_WAIT_MEM =>
                next_state <= S_LOAD;
            when S_LOAD =>
                next_state <= S_EXECUTE;
                next_feed_cnt <= 0;
            when S_EXECUTE =>
                if feed_cnt < (COLS * DATA_WIDTH) - 1 then
                    next_feed_cnt <= feed_cnt + 1;
                else
                    next_state <= S_WAIT_OUT;
                end if;
            when S_WAIT_OUT =>
                if data_valid_out = '1' then
                    if batch_cnt = "0" then
                        next_batch_cnt <= "1";
                        next_feed_cnt <= 0;
                        next_state <= S_EXECUTE; 
                    else
                        next_state <= S_TILE_SWAP;
                    end if;
                end if;
            when S_TILE_SWAP =>
                if tile_cnt = to_unsigned(1, ADDR_WIDTH) then
                    next_state <= S_DONE;
                else
                    next_tile_cnt <= tile_cnt + 1;
                    next_batch_cnt <= "0";
                    next_state <= S_FETCH;
                end if;
            when S_DONE =>
                null;
        end case;
    end process;

    -- process(state, tb_we, tb_sel, tb_addr, tb_din, feed_cnt, input_ram_dout, col_map, tile_cnt, batch_cnt, data_valid_out)
    process(all)
        variable target_id : integer;
        variable bit_offset : integer;
        variable target_logical_row : integer;

        type id_array is array (0 to 3) of integer;
        variable current_tile_ids : id_array;

    begin
        ram_addr <= tb_addr;
        w_ram_din <= tb_din(WEIGHT_BUS_WIDTH-1 downto 0); 
        lut_ram_din <= tb_din(WEIGHT_BUS_WIDTH-1 downto 0);
        input_ram_din <= tb_din(INPUT_BUS_WIDTH-1 downto 0); 
        col_ram_din <= tb_din(COL_GROUP_BUS_WIDTH-1 downto 0); 
        row_ram_din <= tb_din(ROW_ID_BUS_WIDTH-1 downto 0);
        w_ram_we <= '0'; 
        lut_ram_we <= '0'; 
        input_ram_we <= '0'; 
        col_ram_we <= '0'; 
        row_ram_we <= '0';

        en_sa <= '0'; 
        en_in <= '0'; 
        load_w <= '0'; 
        rst_array <= '0'; 
        clear_buffer <= '0'; 
        done <= '0';
        data_in_row <= (others => '0');
        
        output_ram_we <= '0';
        output_ram_addr <= (others => '0');
        w_mat <= w_ram_dout;
        lut_mat <= lut_ram_dout;
        row_ram_din <= row_ram_dout;

        if state = S_IDLE then
            if tb_we = '1' then
                case tb_sel is 
                    when "000" => 
                        w_ram_we <= tb_we;
                        ram_addr <= tb_addr;
                        w_ram_din <= tb_din(WEIGHT_BUS_WIDTH-1 downto 0);
                        tb_dout(WEIGHT_BUS_WIDTH-1 downto 0) <= w_ram_dout;
                        
                    when "001" =>
                        lut_ram_we <= tb_we;
                        ram_addr <= tb_addr;
                        lut_ram_din <= tb_din(WEIGHT_BUS_WIDTH-1 downto 0);
                        tb_dout(WEIGHT_BUS_WIDTH-1 downto 0) <= lut_ram_dout;

                    when "010" =>
                        input_ram_we <= tb_we;
                        ram_addr <= tb_addr;
                        input_ram_din <= tb_din(INPUT_BUS_WIDTH-1 downto 0);
                        tb_dout(INPUT_BUS_WIDTH-1 downto 0) <= input_ram_dout;

                    when "011" => 
                        col_ram_we <= tb_we;
                        ram_addr <= tb_addr;
                        col_ram_din <= tb_din(COL_GROUP_BUS_WIDTH-1 downto 0);
                        tb_dout(COL_GROUP_BUS_WIDTH-1 downto 0) <= col_ram_dout;

                    when "100" => 
                        row_ram_we <= tb_we;
                        ram_addr <= tb_addr;
                        row_ram_din <= tb_din(ROW_ID_BUS_WIDTH-1 downto 0);
                        tb_dout(ROW_ID_BUS_WIDTH-1 downto 0) <= row_ram_dout;

                    when others => NULL;
                end case;
            end if;
        else
            ram_addr <= std_logic_vector(tile_cnt); 
        end if;

        if state = S_EXECUTE or state = S_WAIT_OUT then 
            en_sa <= '1'; 
            en_in <= '1'; 
        end if;

        if state = S_LOAD then 
            load_w <= '1'; 
        end if;

        if state = S_TILE_SWAP then 
            rst_array <= '1'; 
        end if;

        if state = S_DONE then 
            done <= '1'; 
        end if;
        
        if state = S_TILE_SWAP or (state = S_WAIT_OUT and data_valid_out = '1') then 
            clear_buffer <= '1'; 
        end if;

        if state = S_WAIT_OUT and data_valid_out = '1' then
            output_ram_we <= '1';
            output_ram_addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH-2)) & std_logic_vector(tile_cnt(0 downto 0)) & std_logic_vector(batch_cnt(0 downto 0));
            output_ram_din <= sa_y_out;
        end if;

        if state = S_EXECUTE then
            if (feed_cnt mod DATA_WIDTH = 0) and (feed_cnt <= (COLS-1)*DATA_WIDTH) then
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
        end if;

        if start_signal = '0' then
            case tb_sel is
                when "101" =>
                    output_ram_addr <= tb_addr;
                    tb_dout <= output_ram_dout;
                
                when others => null;
            end case;
        end if;



    end process;
end architecture;