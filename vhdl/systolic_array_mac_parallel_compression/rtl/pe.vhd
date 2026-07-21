library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PE is
    generic (
        group_size : positive := 2;
        DATA_WIDTH : positive := 8;
        OUT_WIDTH : positive := 32
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        en            : in  std_logic;
        load_w        : in  std_logic;
        w_in          : in  signed(DATA_WIDTH-1 downto 0);
        x_in          : in  signed(group_size*DATA_WIDTH-1 downto 0);
        y_in          : in  signed(OUT_WIDTH-1 downto 0);
        x_out         : out signed(group_size*DATA_WIDTH-1 downto 0);
        y_out         : out signed(OUT_WIDTH-1 downto 0);
        lut           : in  unsigned(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of PE is
    signal x_out_reg : signed(group_size*DATA_WIDTH-1 downto 0);
    signal lut_reg : unsigned(DATA_WIDTH-1 downto 0);
    signal next_lut : unsigned(DATA_WIDTH-1 downto 0);

    signal mac_out : signed(OUT_WIDTH-1 downto 0);

    signal mac_input : signed(DATA_WIDTH-1 downto 0);
begin

    x_out <= x_out_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                lut_reg <= (others=>'0');
                x_out_reg <= (others=>'0');
            elsif en= '1' then
                lut_reg <= next_lut;
                x_out_reg <= x_in;
            end if;
        end if;
    end process;

    process(load_w, lut, x_in, lut_reg, en)
    variable selected_lane_id : integer;
    begin 
        next_lut <= lut_reg;

        if load_w = '1' then
            next_lut <= lut;
        end if;

        selected_lane_id := to_integer(unsigned(lut_reg));
        if selected_lane_id < group_size then
            mac_input <= x_in(DATA_WIDTH*(selected_lane_id + 1) - 1 downto DATA_WIDTH*selected_lane_id);
        else
            mac_input <= (others=>'0');
        end if;
    end process;

    U_MAC : entity work.MacUnit_parallel
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            OUT_WIDTH => OUT_WIDTH
        )
        port map (
            clk             => clk,
            rst             => rst,
            load_weight     => load_w,
            w               => w_in,
            x               => mac_input,
            partial_sum_in  => y_in,
            partial_sum_out => mac_out,
            x_out           => open    
        );

    y_out <= mac_out;

end architecture;
