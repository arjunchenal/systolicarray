-- ========================================================================================
--  File Name   : macunit_parallel.vhd
--  Author      : Arjun Chenal
--  Created On  : 26-12-2025
--  Description : Synchronous MAC unit. Computes partial_sum_out = partial_sum_in + x*w
-- ========================================================================================



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MacUnit_parallel is
    generic (
        DATA_WIDTH : positive := 8;
        OUT_WIDTH  : positive := 32
    );
    port (
        clk   : in std_logic;
        rst   : in std_logic;
        x     : in signed(DATA_WIDTH-1 downto 0);
        w     : in signed(DATA_WIDTH-1 downto 0);
        load_weight : in std_logic;
        partial_sum_in : in signed(OUT_WIDTH-1 downto 0);
        partial_sum_out : out signed(OUT_WIDTH-1 downto 0);
        x_out : out signed(DATA_WIDTH-1 downto 0)    
    );
end entity MacUnit_parallel;

architecture rtl of MacUnit_parallel is
    signal psum_reg : signed(OUT_WIDTH-1 downto 0);
    signal x_reg    : signed(DATA_WIDTH-1 downto 0);
    signal w_reg    : signed(DATA_WIDTH-1 downto 0);

    signal next_psum : signed(OUT_WIDTH-1 downto 0);
    signal next_x    : signed(DATA_WIDTH-1 downto 0);
    signal next_w    : signed(DATA_WIDTH-1 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                psum_reg <= (others=>'0');
                x_reg <= (others=>'0');
                w_reg <= (others=>'0');
            else
                psum_reg <= next_psum;
                x_reg <= next_x;
                w_reg <= next_w;
            end if;
        end if;
    end process;

    process(psum_reg, w_reg, x, w, load_weight, partial_sum_in)
        variable prod : signed(15 downto 0);
        variable weight : signed(DATA_WIDTH-1 downto 0);
    begin 
        next_psum <= psum_reg;
        next_x <= x;
        next_w <= w_reg;
        
        if load_weight = '1' then
            weight := w;
            next_w <= w;
        else
            weight := w_reg;
        end if;

        prod := x * weight;
        next_psum <= partial_sum_in + resize(prod, OUT_WIDTH);
    end process;

    partial_sum_out <= psum_reg;
    x_out           <= x_reg;

end architecture rtl;
