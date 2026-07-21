
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PE is
    generic (
        ROWS : positive := 4;
        group_size : positive := 2;
        DATA_WIDTH : positive := 8;
        NO_OF_MAC : positive := 4
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        en            : in  std_logic;
        load_w        : in  std_logic;
        w_in          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        x_in          : in  std_logic_vector(group_size-1 downto 0);
        y_in          : in  std_logic_vector(NO_OF_MAC-1 downto 0);
        x_out         : out std_logic_vector(group_size-1 downto 0);
        y_out         : out std_logic_vector(NO_OF_MAC-1 downto 0);
        en_out        : out std_logic;
        lut           : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mac_valid_out : out std_logic_vector(NO_OF_MAC-1 downto 0)
    );
end entity PE;

architecture rtl of PE is
    signal mac_run_timer_reg : unsigned(4 downto 0);
    signal lut_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal x_out_reg : std_logic_vector(group_size-1 downto 0);
    signal en_reg : std_logic; 
    signal mac_x_in_reg : std_logic_vector(NO_OF_MAC-1 downto 0);
    signal mac_new_input_start_reg : std_logic_vector(NO_OF_MAC-1 downto 0);
    signal mac_en_in_reg : std_logic_vector(NO_OF_MAC-1 downto 0);
    signal load_w_reg : std_logic;

    
    signal next_lut_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal next_x_out_reg : std_logic_vector(group_size-1 downto 0);
    signal next_mac_run_timer_reg :  unsigned(4 downto 0);
    signal next_mac_x_in_reg : std_logic_vector(NO_OF_MAC-1 downto 0);
    signal next_mac_new_input_start_reg : std_logic_vector(NO_OF_MAC-1 downto 0);
    signal next_mac_en_in_reg : std_logic_vector(NO_OF_MAC-1 downto 0);


    -- combinitional
    signal mac_y_internal : std_logic_vector(NO_OF_MAC-1 downto 0);

begin

    x_out         <= x_out_reg;
    y_out         <= mac_y_internal; 
    mac_valid_out <= mac_en_in_reg;
    en_out        <= en_reg; 
 
    --sequential
    process(clk)
    begin 
        if rising_edge(clk) then
            if rst = '1' then
                lut_reg <= (others=>'0');
                x_out_reg <= (others=>'0');
                mac_run_timer_reg <= (others=>'0');
                en_reg <= '0';
                mac_x_in_reg <= (others=>'0');
                mac_new_input_start_reg <= (others=>'0');
                mac_en_in_reg <= (others=>'0');
            else
                load_w_reg <= load_w;
                lut_reg <= next_lut_reg;
                x_out_reg <= next_x_out_reg;
                mac_run_timer_reg <= next_mac_run_timer_reg;
                en_reg <= en; 
                mac_x_in_reg <= next_mac_x_in_reg; 
                mac_new_input_start_reg <= next_mac_new_input_start_reg;
                mac_en_in_reg <= next_mac_en_in_reg;
            end if;
        end if;
    end process;

    -- combinitional
    process(all)
        variable selected_lane_id   : integer;
        variable active_input_bit   : std_logic;
    begin 
        next_lut_reg <= lut_reg;
        next_x_out_reg <= x_out_reg;
        next_mac_run_timer_reg <= mac_run_timer_reg;
        next_mac_x_in_reg <= (others=>'0');
        next_mac_en_in_reg <= (others=>'0');
        next_mac_new_input_start_reg <= (others=>'0');

        next_x_out_reg <= x_in;
 
        if load_w_reg = '1' then
            next_lut_reg <= lut;
        end if;

        if en = '1' then
            next_mac_en_in_reg <= (others=>'1');

            selected_lane_id := to_integer(unsigned(lut_reg));  
            if selected_lane_id < group_size then
                active_input_bit := x_in(selected_lane_id);    
            else
                active_input_bit := '0';
            end if;

            for i in 0 to NO_OF_MAC-1 loop
                if i = to_integer(mac_run_timer_reg(4 downto 3)) then
                    next_mac_x_in_reg(i) <= active_input_bit;
                    if mac_run_timer_reg(2 downto 0) = "000" then 
                        next_mac_new_input_start_reg(i) <= '1';
                    else
                        next_mac_new_input_start_reg(i) <= '0';
                    end if;
                else
                    next_mac_x_in_reg(i) <= '0';
                    next_mac_new_input_start_reg(i) <= '0';
                end if;
            end loop;

            next_mac_run_timer_reg <= mac_run_timer_reg + 1;
        end if;
    end process;

    -- MAC Serial
    gen_mac : for i in 0 to NO_OF_MAC-1 generate
        serial_mac : entity work.macunit_serial
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk     => clk,
            rst     => rst,
            en      => mac_en_in_reg(i),
            load_w  => load_w_reg,
            w_in    => w_in,
            start   => mac_new_input_start_reg(i),
            x_in    => mac_x_in_reg(i),
            y_in    => y_in(i),
            x_out   => open,
            y_out   => mac_y_internal(i),
            en_out  => open
        );
    end generate;
end architecture;

 
