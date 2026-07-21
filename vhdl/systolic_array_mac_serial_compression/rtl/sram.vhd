-- ==============================================================================================================================================
--  File Name   : SRAM.vhd
--  Author      : Arjun Chenal
--  Created On  : 26-12-2025
--  Description : Synchronous SRAM
-- ==============================================================================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram is
    generic (
        ADDR_WIDTH : integer := 4; 
        DATA_WIDTH : integer := 32
    );
    port (
        clk  : in std_logic;
        we   : in std_logic; 
        re   : in std_logic;
        addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dout : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of sram is
    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_type;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
            
            if re = '1' then
                dout <= ram(to_integer(unsigned(addr)));
            end if;
        end if;
    end process;
end architecture;