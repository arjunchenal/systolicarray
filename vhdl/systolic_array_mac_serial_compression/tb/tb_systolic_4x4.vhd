library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pe_grid_4x4 is
end entity;

architecture tb of tb_pe_grid_4x4 is
    constant DATA_WIDTH : integer := 8;
    constant ROWS : integer := 4;
    constant COLS : integer := 4;
    constant NO_OF_MAC : integer := 4;
    constant group_size : integer := 4;
    constant clk_period : time := 10 ns;
    constant OUT_WIDTH : integer := 32;
    constant MAX_OUTPUT_ROWS_WIDTH : integer := 3;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal load_w : std_logic := '0';

    signal en_sa : std_logic := '0';  
    signal en_in : std_logic := '0';
    signal clear_pipeline : std_logic := '0';
    signal x_col_bits : std_logic_vector((COLS*group_size)-1 downto 0);     
    signal w_mat : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);  
    signal lut_mat : std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);  
    signal lane_valid_bits : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);  


    signal y_row_bits : std_logic_vector(ROWS*NO_OF_MAC-1 downto 0);  
    signal row_id_data_in : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);  
    signal row_id_data_out : std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);  

    -- input register array
    signal data_in_row : std_logic_vector((COLS*group_size*DATA_WIDTH)-1 downto 0);

begin


    clk <= not clk after clk_period/2;

    systolic_array: entity work.SystolicArray_serial
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ROWS => ROWS,
            COLS => COLS,
            group_size => group_size,
            MAX_OUTPUT_ROWS_WIDTH => MAX_OUTPUT_ROWS_WIDTH,
            NO_OF_MAC => NO_OF_MAC
        )
        port map (
            clk => clk,
            rst => rst,
            en => en_sa,
            load_w => load_w,
            x_col_bits => x_col_bits,   
            w_mat => w_mat,
            lut_mat => lut_mat,
            y_row_bits => y_row_bits,
            lane_valid_bits => lane_valid_bits,
            row_id_data_in => row_id_data_in,
            row_id_data_out => row_id_data_out
        );


    input_register_array : entity work.InputRegisterArray
        generic map(
            COLS => COLS,
            DATA_WIDTH => DATA_WIDTH,
            group_size => group_size
        )
        port map(
            clk => clk,
            rst => rst,
            en  => en_in,
            clear_pipeline => clear_pipeline,
            data_in_row => data_in_row,
            data_to_cols => x_col_bits
        );

    stim_proc: process
    variable input : std_logic_vector(39 downto 0);
    variable id : integer;
    variable output_mac0 : std_logic_vector(31 downto 0);
    variable output_mac1 : std_logic_vector(31 downto 0);
    variable output_mac2 : std_logic_vector(31 downto 0);
    variable output_mac3 : std_logic_vector(31 downto 0);
    variable output_mac00 : std_logic_vector(31 downto 0);

    variable LATENCY : integer := 3;
    begin

        report " Systolic Array GRID TB ";

        rst <= '1';
        en_sa <= '0';
        en_in <= '0';
        load_w <= '0';
 
        wait for 30 ns;
        wait until rising_edge(clk);
        rst <='0';
        wait until rising_edge(clk);

        -- weight and LUT loading
        for r in 0 to ROWS-1 loop 
            for c in 0 to COLS-1 loop 
                id := r*COLS + c;
                w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
                lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH) <= std_logic_vector(to_unsigned(0, DATA_WIDTH));
            end loop;
        end loop;

        load_w <= '1';
        wait until rising_edge(clk);
        load_w <= '0';
  
        en_sa <= '1';
        en_in <= '1';

        
        for i in 0 to 179 loop 
            if i = 0 then
                data_in_row <= (others => '0');
                data_in_row(7 downto 0)   <= std_logic_vector(to_unsigned(4, DATA_WIDTH)); 
                data_in_row(39 downto 32) <= std_logic_vector(to_unsigned(8, DATA_WIDTH)); 
                
            elsif i = 8 then
                data_in_row <= (others => '0');
                data_in_row(7 downto 0)   <= std_logic_vector(to_unsigned(5, DATA_WIDTH));
                data_in_row(39 downto 32) <= std_logic_vector(to_unsigned(9, DATA_WIDTH));
                
            elsif i = 16 then
                data_in_row <= (others => '0');
                data_in_row(7 downto 0)   <= std_logic_vector(to_unsigned(6, DATA_WIDTH));
                data_in_row(39 downto 32) <= std_logic_vector(to_unsigned(10, DATA_WIDTH));
                
            elsif i = 24 then
                data_in_row <= (others => '0');
                data_in_row(7 downto 0)   <= std_logic_vector(to_unsigned(7, DATA_WIDTH));
                data_in_row(39 downto 32) <= std_logic_vector(to_unsigned(11, DATA_WIDTH));
                
            elsif i = 32 then
                data_in_row <= (others => '0');
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;  

            if i >= LATENCY and i < (LATENCY + 32) then
                output_mac0(i - LATENCY) := y_row_bits(0);
            end if;

            if i >= (8 + LATENCY) and i < (8 + LATENCY + 32) then
                output_mac1(i - (8 + LATENCY)) := y_row_bits(1);
            end if;

            if i >= (16 + LATENCY) and i < (16 + LATENCY + 32) then
                output_mac2(i - (16 + LATENCY)) := y_row_bits(2);
            end if;

            if i >= (24 + LATENCY) and i < (24 + LATENCY + 32) then
                output_mac3(i - (24 + LATENCY)) := y_row_bits(3);
            end if;

        end loop;
        report "MAC 0 Result (40 + 80): "  & integer'image(to_integer(unsigned(output_mac0)));
        report "MAC 1 Result (50 + 90): "  & integer'image(to_integer(unsigned(output_mac1)));
        report "MAC 2 Result (60 + 100): " & integer'image(to_integer(unsigned(output_mac2)));
        report "MAC 3 Result (70 + 110): " & integer'image(to_integer(unsigned(output_mac3)));

        if to_integer(unsigned(output_mac0)) = 120 and 
           to_integer(unsigned(output_mac1)) = 140 and
           to_integer(unsigned(output_mac2)) = 160 and
           to_integer(unsigned(output_mac3)) = 180 then            
             report "correct";
        else
             report "error" severity error;
        end if;

        en_sa <= '0';
        wait;
    end process;



end architecture;