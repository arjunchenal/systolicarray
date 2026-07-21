-- ========================================================================================================================================
--  File Name   : systolic_array.vhd
--  Author      : Arjun Chenal
--  Created On  : 26-12-2025
--  Description : grid of macunit for matrix multiplication. X inputs are fed from bottom and go vertically upwards. Weights stay constant in PE.
-- ========================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SystolicArray is
    generic (
        ROWS : positive := 2;
        COLS : positive := 2;
        DATA_WIDTH : positive := 8;
        OUT_WIDTH : positive := 32;
        group_size : positive := 2; 
        ADDR_WIDTH : positive := 4
    );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        load_weight : in std_logic;
        x_bottom_bus : in  std_logic_vector(group_size*COLS*DATA_WIDTH-1 downto 0);
        w_mat        : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        lut_mat        : in  std_logic_vector(ROWS*COLS*DATA_WIDTH-1 downto 0);
        y_out_bus    : out std_logic_vector(ROWS*OUT_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of SystolicArray is
    subtype s8  is signed(group_size*DATA_WIDTH - 1 downto 0);
    subtype s32 is signed(OUT_WIDTH-1 downto 0);
    type s8_mat  is array (0 to ROWS-1, 0 to COLS-1) of s8;
    type s32_mat is array (0 to ROWS-1, 0 to COLS-1) of s32;
    type lut_matrix is array(0 to ROWS-1, 0 to COLS-1) of unsigned(DATA_WIDTH-1 downto 0);
    type weight_matrix is array(0 to ROWS-1, 0 to COLS-1) of signed(DATA_WIDTH-1 downto 0);
    signal x_in   : s8_mat;
    signal x_out  : s8_mat;
    signal lut_pe : lut_matrix;
    signal psum_in  : s32_mat;
    signal psum_out : s32_mat;
    signal w_pe : weight_matrix;
begin

    -- inputs for bottom most row PE00 PE01 PE02 PE03
    gen_x_bottom: for c in 0 to COLS-1 generate
    constant upper_bit : integer := (c+1)*group_size*DATA_WIDTH - 1;
    constant lower_bit : integer := c * group_size * DATA_WIDTH;
    begin
        x_in(0, c) <= signed(x_bottom_bus(upper_bit downto lower_bit));
    end generate;

    -- weights
    gen_weight_r: for r in 0 to ROWS-1 generate
        gen_weight_c: for c in 0 to COLS-1 generate
        constant id : integer := r*COLS + c;
        begin
            w_pe(r,c) <= signed(w_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH));
            lut_pe(r,c) <= unsigned(lut_mat((id+1)*DATA_WIDTH-1 downto id*DATA_WIDTH));
        end generate;
    end generate;

    -- X input movement from bottom to top PE
    gen_x_vertical: for r in 1 to ROWS-1 generate
        gen_x_vertical_c: for c in 0 to COLS-1 generate
        begin
            x_in(r, c) <= x_out(r-1, c);
        end generate;
    end generate;

    -- partial sum for left most PE setting to 0
    gen_psum_left: for r in 0 to ROWS-1 generate
    begin
        psum_in(r, 0) <= (others => '0');
    end generate;

    -- partial sum coming from left PE to right PE
    gen_psum_horizontal: for r in 0 to ROWS-1 generate
        gen_psum_horizontal_c: for c in 1 to COLS-1 generate
        begin
            psum_in(r, c) <= psum_out(r, c-1);
        end generate;
    end generate;

    -- PE grid
    gen_pe_r: for r in 0 to ROWS-1 generate
        gen_pe_c: for c in 0 to COLS-1 generate
        begin
            PE: entity work.PE
                generic map(
                    DATA_WIDTH => DATA_WIDTH,
                    OUT_WIDTH => OUT_WIDTH,
                    group_size => group_size
                )
                port map (
                    clk             => clk,
                    rst             => rst,
                    en              => '1',
                    load_w          => load_weight,
                    x_in            => x_in(r, c),
                    w_in            => w_pe(r, c),
                    lut             => lut_pe(r,c),
                    y_in            => psum_in(r, c),
                    y_out           => psum_out(r, c),
                    x_out           => x_out(r, c)
                );
        end generate;
    end generate;

    -- fetching output from rightmost PE
    gen_output: for r in 0 to ROWS-1 generate
    begin
        y_out_bus((r+1)*OUT_WIDTH-1 downto r*OUT_WIDTH) <= std_logic_vector(psum_out(r, COLS-1));
    end generate;
end architecture;
