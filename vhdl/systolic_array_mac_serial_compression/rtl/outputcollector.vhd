library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity OutputBuffer is
    generic (
        ROWS      : integer := 4;
        COLS      : integer := 4;
        NO_OF_MAC : integer := 4;
        OUT_WIDTH : integer := 32;
        MAX_OUTPUT_ROWS_WIDTH : integer := 3
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        array_en       : in  std_logic;
        y_serial_in    : in  std_logic_vector((ROWS*NO_OF_MAC)-1 downto 0);
        row_ids_in     : in  std_logic_vector(ROWS*MAX_OUTPUT_ROWS_WIDTH-1 downto 0);
        clear_buffer   : in  std_logic; 
        y_parallel_out : out std_logic_vector((ROWS*NO_OF_MAC*OUT_WIDTH)-1 downto 0);
        data_valid_out : out std_logic  
    );
end entity;

architecture rtl of OutputBuffer is
    type shift_array is array (0 to (ROWS*NO_OF_MAC)-1) of std_logic_vector(OUT_WIDTH-1 downto 0);
    signal shift_regs   : shift_array;
    signal master_timer : unsigned(15 downto 0);
    
    constant MAX_END_TIME : integer := COLS + (ROWS-1) + ((NO_OF_MAC-1)*8) + OUT_WIDTH;
begin
    process(clk)
        variable row_idx, mac_idx, start_time, end_time : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' or clear_buffer = '1' then
                master_timer <= (others => '0');
                data_valid_out <= '0';
                for i in 0 to (ROWS*NO_OF_MAC)-1 loop
                    shift_regs(i) <= (others => '0');
                end loop;
            else
                if array_en = '1' then 
                    master_timer <= master_timer + 1; 
                end if;

                for i in 0 to (ROWS*NO_OF_MAC)-1 loop
                    row_idx := i / NO_OF_MAC;
                    mac_idx := i rem NO_OF_MAC;
                    start_time := COLS + (row_idx * 1) + (mac_idx * 8);
                    end_time   := start_time + OUT_WIDTH;

                    if master_timer >= start_time and master_timer < end_time then
                        shift_regs(i) <= y_serial_in(i) & shift_regs(i)(OUT_WIDTH-1 downto 1);
                    end if;
                end loop;
                
                if master_timer = MAX_END_TIME then
                    data_valid_out <= '1';
                end if;
                
            end if;
        end if;
    end process;

    process(shift_regs, row_ids_in)
        variable target_logical_row : integer;
        variable phys_lane, log_lane : integer;
        variable local_lane : integer;
    begin
        y_parallel_out <= (others => '0');
        for r in 0 to ROWS-1 loop
            target_logical_row := to_integer(unsigned(row_ids_in((r*MAX_OUTPUT_ROWS_WIDTH)+(MAX_OUTPUT_ROWS_WIDTH-1) downto r*MAX_OUTPUT_ROWS_WIDTH)));
            for m in 0 to NO_OF_MAC-1 loop
                phys_lane := (r * NO_OF_MAC) + m;
                log_lane  := (target_logical_row * NO_OF_MAC) + m;
                y_parallel_out((log_lane+1)*OUT_WIDTH-1 downto log_lane*OUT_WIDTH) <= shift_regs(phys_lane);
            end loop;
        end loop;
    end process;

end architecture;





 