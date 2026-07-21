
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all; 

entity tb_systolic_sram is
end entity;

architecture tb of tb_systolic_sram is
    constant ROWS       : integer := 4;
    constant COLS       : integer := 4;
    constant input_row : integer := 8;
    constant input_col : integer := 8;
    constant ADDR_WIDTH : integer := 4;
    constant CLK_PERIOD : time    := 10 ns;
    constant NO_OF_MAC : integer := 4;
    constant group_size : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant weight_rows : integer := 8;
    constant weight_cols : integer := 8;
    constant output_width_total : integer := ROWS*NO_OF_MAC*32;
    constant IS_COMPRESSED : boolean := true;
    constant OUT_WIDTH : integer := 32;
    constant LATENCY : integer := 10;

    constant MAX_OUTPUT_ROWS_WIDTH : positive := 3;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal start_signal : std_logic := '0';
    signal tb_sel       : std_logic_vector(2 downto 0) := "000";
    signal tb_we        : std_logic := '0';
    signal tb_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal tb_data_in   : std_logic_vector(output_width_total-1 downto 0) := (others => '0');
    signal tb_data_out  : std_logic_vector(output_width_total-1 downto 0) := (others => '0');

    signal w_ram_din, w_ram_dout, lut_ram_din, lut_ram_dout : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0) := (others => '0');
    signal o_ram_din, o_ram_dout : std_logic_vector(output_width_total-1 downto 0):= (others => '0');
    signal i_ram_din, i_ram_dout : std_logic_vector(input_col*DATA_WIDTH-1 downto 0):= (others => '0');
    signal w_ram_addr, i_ram_addr, o_ram_addr, lut_ram_addr, row_id_ram_addr, col_group_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal w_ram_we, i_ram_we, o_ram_we, lut_ram_we, row_id_ram_we, col_group_ram_we : std_logic;

    signal col_group_ram_din, col_group_ram_dout : std_logic_vector(COLS*group_size*DATA_WIDTH-1 downto 0) := (others=>'0');


    signal row_id_ram_din, row_id_ram_dout : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0) := (others => '0');

    signal number_of_tiles : std_logic_vector(1 downto 0);

    function hex_to_str(slv : std_logic_vector) return string is
        variable L : line;
    begin
        hwrite(L, slv);
        return L.all;
    end function;

begin

    u_accel: entity work.Accelerator
        generic map ( 
            ROWS => ROWS, 
            COLS => COLS, 
            ADDR_WIDTH => ADDR_WIDTH,
            NO_OF_MAC => NO_OF_MAC,
            group_size => group_size,
            DATA_WIDTH => DATA_WIDTH,
            input_row => input_row,
            input_col => input_col,
            IS_COMPRESSED => IS_COMPRESSED,
            WEIGHT_ROWS  => weight_rows,
            WEIGHT_COLS => weight_cols,
            OUT_WIDTH => OUT_WIDTH,
            LATENCY => LATENCY,
            MAX_OUTPUT_ROWS_WIDTH => MAX_OUTPUT_ROWS_WIDTH
            )
        port map (
            clk => clk, 
            rst => rst, 
            start_signal => start_signal,
            tb_sel => tb_sel, 
            tb_we => tb_we, 
            tb_addr => tb_addr, 
            tb_din => tb_data_in, 
            tb_dout => tb_data_out,
            w_ram_addr => w_ram_addr, 
            w_ram_din => w_ram_din, 
            w_ram_we => w_ram_we, 
            w_ram_dout => w_ram_dout,
            lut_ram_addr => lut_ram_addr, 
            lut_ram_din => lut_ram_din, 
            lut_ram_we => lut_ram_we, 
            lut_ram_dout => lut_ram_dout,
            row_id_ram_addr => row_id_ram_addr,
            row_id_ram_din => row_id_ram_din,
            row_id_ram_we => row_id_ram_we,
            row_id_ram_dout => row_id_ram_dout,

            col_group_ram_addr => col_group_ram_addr,
            col_group_ram_din => col_group_ram_din,
            col_group_ram_we => col_group_ram_we,
            col_group_ram_dout => col_group_ram_dout,

            i_ram_addr => i_ram_addr, 
            i_ram_din => i_ram_din, 
            i_ram_we => i_ram_we, 
            i_ram_dout => i_ram_dout,
            o_ram_addr => o_ram_addr, 
            o_ram_din => o_ram_din, 
            o_ram_we => o_ram_we, 
            o_ram_dout => o_ram_dout,
            number_of_tiles => number_of_tiles
        );

    -- weight sram PE is 4x4 so 4x4xDATA_WIDTH bits can be loaded max in one tile
    u_ram_w: entity work.sram 
        generic map ( 
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => ROWS*COLS*DATA_WIDTH
        ) 
        port map ( 
            clk => clk, 
            we => w_ram_we, 
            re => '1', 
            addr => w_ram_addr, 
            din => w_ram_din, 
            dout => w_ram_dout 
        );

    u_ram_lut: entity work.sram 
        generic map ( 
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => ROWS*COLS*DATA_WIDTH 
        ) 
        port map ( 
            clk => clk, 
            we => lut_ram_we, 
            re => '1', 
            addr => lut_ram_addr, 
            din => lut_ram_din, 
            dout => lut_ram_dout 
        );

    -- Column group which tells how to pack input columns to PE
    u_ram_col: entity work.sram
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => COLS*group_size*DATA_WIDTH
        )
        port map(
            clk => clk, 
            we => col_group_ram_we, 
            re => '1', 
            addr => col_group_ram_addr, 
            din => col_group_ram_din, 
            dout => col_group_ram_dout 
        );

    u_ram_row_id: entity work.sram 
        generic map ( 
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => ROWS*MAX_OUTPUT_ROWS_WIDTH
        ) 
        port map (
            clk => clk, 
            we => row_id_ram_we, 
            re => '1', 
            addr => row_id_ram_addr, 
            din => row_id_ram_din, 
            dout => row_id_ram_dout 
        );

    u_ram_i: entity work.sram 
        generic map ( 
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => input_col*DATA_WIDTH 
            )  
        port map ( 
            clk => clk, 
            we => i_ram_we, 
            re => '1', 
            addr => i_ram_addr, 
            din => i_ram_din, 
            dout => i_ram_dout 
        );

    u_ram_o: entity work.sram 
        generic map ( 
            ADDR_WIDTH => ADDR_WIDTH, 
            DATA_WIDTH => output_width_total
        ) 
        port map ( 
            clk => clk, 
            we => o_ram_we, 
            re => '1', 
            addr => o_ram_addr, 
            din => o_ram_din, 
            dout => o_ram_dout 
        );

    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim: process
        file file_weights : text open read_mode is "weights.mem";
        file file_lut_index : text open read_mode is "lut_index.mem";
        file file_inputs  : text open read_mode is "inputs.mem";
        file file_output  : text open read_mode is "output.mem";
        file file_row_id_data : text open read_mode is "row_id_data.mem";
        file file_col_group_data : text open read_mode is "col_group_data.mem";

        variable current_line : line;
        variable weight_data  : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        variable lut_index_data : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        variable row_id_data : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
        variable col_group_data : std_logic_vector(COLS*group_size*DATA_WIDTH-1 downto 0);
        variable input_data   : std_logic_vector(input_col*DATA_WIDTH-1 downto 0);
        variable output_data  : std_logic_vector(output_width_total-1 downto 0);
        variable v_addr_id    : integer := 0;

        variable d : integer;
        variable index_start   : integer;
        variable index_end  : integer;
        variable value     : integer;
        variable value_expected     : integer;
    begin
        rst          <= '1';
        tb_we        <= '0';
        tb_sel       <= "000";
        tb_addr      <= (others => '0');
        tb_data_in   <= (others => '0');
        start_signal <= '0';

        number_of_tiles <= "10";

        wait for 40 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- Weight
        report "Weight";
        tb_sel <= "000";
        v_addr_id := 0;
        while not endfile(file_weights) loop
            readline(file_weights, current_line);
            hread(current_line, weight_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(ROWS*COLS*DATA_WIDTH-1 downto 0) <= weight_data;      
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk); 
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
            tb_data_in <= (others => '0');
            tb_data_in(ROWS*COLS*DATA_WIDTH-1 downto 0) <= lut_index_data;      
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk); 
            v_addr_id := v_addr_id + 1;
        end loop;

        -- ROW ID DATA
        report "ROW ID Data";
        tb_sel <= "010";
        v_addr_id := 0;
        while not endfile(file_row_id_data) loop
            readline(file_row_id_data, current_line);
            hread(current_line, row_id_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0) <= row_id_data;      
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk); 
            v_addr_id := v_addr_id + 1;
        end loop;


        -- COL GROUP DATA
        report "COL GROUP Data";
        tb_sel <= "011";
        v_addr_id := 0;
        while not endfile(file_col_group_data) loop
            readline(file_col_group_data, current_line);
            hread(current_line, col_group_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(COLS*group_size*DATA_WIDTH-1 downto 0) <= col_group_data;      
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk); 
            v_addr_id := v_addr_id + 1;
        end loop;

        -- Input
        report "Inputs";
        tb_sel <= "100";
        v_addr_id := 0;
        while not endfile(file_inputs) loop
            readline(file_inputs, current_line);
            hread(current_line, input_data);
            tb_addr    <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(input_col*DATA_WIDTH-1 downto 0) <= input_data;    
            tb_we <= '1';
            wait until rising_edge(clk); 
            tb_we <= '0'; 
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;

        -- start
        report "Start";
        wait for 20 ns;
        start_signal <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        start_signal <= '0';

        wait for 2000 ns;

        report "verify";
        tb_sel <= "101";
        tb_we  <= '0';
        
        tb_addr <= (others => '0');
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        if not endfile(file_output) then
            readline(file_output, current_line);
            hread(current_line, output_data); 
            
                for i in 0 to (ROWS*NO_OF_MAC)-1 loop   
                    index_start   := i*32;
                    index_end  := index_start + 31;
                    
                    value := to_integer(unsigned(tb_data_out(index_end downto index_start)));
                    value_expected := to_integer(unsigned(output_data(index_end downto index_start)));
                    
                    if value /= value_expected then
                       report "error at index " & integer'image(i) &  " expected: " & integer'image(value_expected) &  " got: " & integer'image(value) 
                              severity error;
                   else
                       report "match at index " & integer'image(i) &  " got: " & integer'image(value);
                   end if;
                end loop;
        end if;

        report "Test complete";
        wait;
    end process;

end architecture;