library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all; 

entity tb_systolic_sram is
end entity;

architecture tb of tb_systolic_sram is
    constant ROWS : integer := 4;
    constant COLS : integer := 4;
    constant ADDR_WIDTH : integer := 4;
    constant DATA_WIDTH : integer := 8;
    constant OUT_WIDTH : integer := 32;
    constant group_size : integer := 2;

    constant input_matrix_row : integer := 4;
    constant input_matrix_col : integer := 8;
    constant weight_matrix_row : integer := 4;
    constant weight_matrix_col : integer := 4;

    constant tb_width_output : integer := input_matrix_row*weight_matrix_col*OUT_WIDTH;

    constant IS_COMPRESSED : boolean := true;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    signal start_signal : std_logic := '0';
    signal tb_sel       : std_logic_vector(1 downto 0) := "00";
    signal tb_we        : std_logic := '0';
    signal tb_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal tb_data_in   : std_logic_vector(tb_width_output-1 downto 0) := (others => '0');
    signal tb_data_out  : std_logic_vector(tb_width_output-1 downto 0);


    signal w_ram_din, w_ram_dout, lut_ram_din, lut_ram_dout  : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
    signal o_ram_din, o_ram_dout : std_logic_vector(ROWS*COLS*32-1 downto 0);
    signal i_ram_din, i_ram_dout : std_logic_vector(input_matrix_col*8-1 downto 0);  -- input column 
    
    signal w_ram_addr, i_ram_addr, o_ram_addr, lut_ram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal w_ram_we, i_ram_we, o_ram_we, lut_ram_we : std_logic;
    
    constant clk_period : time := 10 ns;

begin

    u_accel: entity work.Accelerator
        generic map ( 
            ROWS => ROWS, 
            COLS => COLS, 
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            OUT_WIDTH => OUT_WIDTH,
            group_size => group_size,
            input_matrix_row => input_matrix_row,
            input_matrix_col => input_matrix_col,
            weight_matrix_row => weight_matrix_row,
            weight_matrix_col => weight_matrix_col,
            tb_width_output   => tb_width_output,
            IS_COMPRESSED => IS_COMPRESSED
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
            i_ram_addr => i_ram_addr, 
            i_ram_din => i_ram_din, 
            i_ram_we => i_ram_we, 
            i_ram_dout => i_ram_dout,
            o_ram_addr => o_ram_addr, 
            o_ram_din => o_ram_din, 
            o_ram_we => o_ram_we, 
            o_ram_dout => o_ram_dout
        );

    -- weight sram
    u_ram_w: entity work.sram 
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => ROWS*COLS*DATA_WIDTH
        ) 
        port map (
            clk => clk, 
            we => w_ram_we, 
            re =>'1', 
            addr => w_ram_addr, 
            din => w_ram_din, 
            dout => w_ram_dout
        );

    -- lut sram
    u_ram_lut: entity work.sram 
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => ROWS*COLS*DATA_WIDTH
        ) 
        port map (
            clk => clk, 
            we => lut_ram_we, 
            re =>'1', 
            addr => lut_ram_addr, 
            din => lut_ram_din, 
            dout => lut_ram_dout
        );

    -- input sram
    u_ram_i: entity work.sram 
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => input_matrix_col*DATA_WIDTH
        )  
        port map (
            clk => clk, 
            we => i_ram_we, 
            re => '1', 
            addr => i_ram_addr, 
            din => i_ram_din, 
            dout => i_ram_dout
        );

    -- output sram
    u_ram_o: entity work.sram 
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => ROWS*COLS*OUT_WIDTH
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
        while true loop
            clk <= '0'; wait for clk_period/2;
            clk <= '1'; wait for clk_period/2;
        end loop;
    end process;

    stim: process

        file file_weights  : text open read_mode is "weights.txt";
        file file_inputs   : text open read_mode is "inputs.txt";
        file file_output : text open read_mode is "output.txt";
        file file_lut    : text open read_mode is "lut_index.txt";

        variable current_line : line;
        variable weight_data   : std_logic_vector(weight_matrix_row*weight_matrix_col*DATA_WIDTH-1 downto 0);
        variable output_data   : std_logic_vector(weight_matrix_col*OUT_WIDTH-1 downto 0);
        variable input_data    : std_logic_vector(input_matrix_col*DATA_WIDTH-1 downto 0);
        variable lut_index_data : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        variable v_addr_id   : integer := 0;

        variable output_sram : std_logic_vector(weight_matrix_col*OUT_WIDTH-1 downto 0);


        variable d : integer;
        variable index_start   : integer;
        variable index_end  : integer;
        variable value     : integer;
        variable value_expected     : integer;
        variable index_start_sram     : integer;
        variable index_end_sram     : integer;

    begin
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;

        report "Weight Load.";
        tb_sel <= "00"; 
        v_addr_id := 0;
        
        while not endfile(file_weights) loop
            readline(file_weights, current_line);
            hread(current_line, weight_data);
            
            tb_addr <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(weight_matrix_row*weight_matrix_col*DATA_WIDTH-1 downto 0) <= weight_data;  
            tb_we <= '1';
            
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;

        tb_we <= '0';
        wait until rising_edge(clk);

        report "LUT Load.";
        tb_sel <= "11"; 
        v_addr_id := 0;
        
        while not endfile(file_lut) loop
            readline(file_lut, current_line);
            hread(current_line, lut_index_data);
            
            tb_addr <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0');
            tb_data_in(ROWS*COLS*DATA_WIDTH-1 downto 0) <= lut_index_data;  
            tb_we <= '1';
            
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;


        tb_we <= '0';
        wait until rising_edge(clk);

        report "Input load";
        tb_sel <= "01";
        v_addr_id := 0;
        
        while not endfile(file_inputs) loop
            readline(file_inputs, current_line);
            hread(current_line, input_data);
            
            tb_addr <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            tb_data_in <= (others => '0'); 
            tb_data_in(input_matrix_col*DATA_WIDTH-1 downto 0) <= input_data;
            tb_we <= '1';
            
            wait until rising_edge(clk);
            v_addr_id := v_addr_id + 1;
        end loop;
        tb_we <= '0';

        report "start";
        wait for 20 ns;
        start_signal <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        start_signal <= '0';

        wait for 3000 ns;

        report "verification";
        tb_sel <= "10";
        tb_we  <= '0';
        v_addr_id := 0;
        while not endfile(file_output) loop

            tb_addr <= std_logic_vector(to_unsigned(v_addr_id, ADDR_WIDTH));
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            for j in 0 to ROWS-1 loop
                if not endfile(file_output) then
                    readline(file_output, current_line);
                    hread(current_line, output_data); 
                end if;

                for r in 0 to weight_matrix_col-1 loop
                
                    index_start := r * OUT_WIDTH;
                    index_end   := index_start + OUT_WIDTH - 1;
                    value_expected := to_integer(unsigned(output_data(index_end downto index_start)));
                    index_start_sram := r*(ROWS*OUT_WIDTH) + j*OUT_WIDTH;
                    index_end_sram := index_start_sram + OUT_WIDTH - 1;
                    value := to_integer(unsigned(tb_data_out(index_end_sram downto index_start_sram)));
                    
                    if value /= value_expected then
                        report "error at index " & integer'image(r) &  " expected: " & integer'image(value_expected) &  " got: " & integer'image(value)  
                            severity error;
                    else
                        report "Match at index " & integer'image(j) & integer'image(r) & " the matching value is :" & integer'image(value);
                    end if;

                end loop;
        end loop;

        v_addr_id := v_addr_id + 1;
        
    end loop;

        wait;
    end process;

end architecture;

