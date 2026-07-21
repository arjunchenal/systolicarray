library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity macunit_hybrid is
    generic (
        DATA_WIDTH  : positive := 8;   
        INPUT_DATA_RADIX : positive := 4 
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        en     : in  std_logic;
        load_w : in  std_logic;
        start  : in  std_logic;
        w_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        x_in   : in  std_logic_vector(INPUT_DATA_RADIX-1 downto 0);  
        y_in   : in  std_logic_vector(INPUT_DATA_RADIX-1 downto 0);  
        x_out  : out std_logic_vector(INPUT_DATA_RADIX-1 downto 0);   
        y_out  : out std_logic_vector(INPUT_DATA_RADIX-1 downto 0);   
        en_out : out std_logic
    );
end entity;

architecture rtl of macunit_hybrid is

    signal w_reg         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sum_reg       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal carry_reg     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal acc_sum_reg   : std_logic_vector(INPUT_DATA_RADIX-1 downto 0);
    signal acc_carry_reg : std_logic;
    signal en_reg        : std_logic;

    signal next_sum       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal next_carry     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal next_acc_sum   : std_logic_vector(INPUT_DATA_RADIX-1 downto 0);
    signal next_acc_carry : std_logic;

begin

    x_out  <= x_in;
    en_out <= en_reg;
    y_out  <= acc_sum_reg;


    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                w_reg         <= (others => '0');
                sum_reg       <= (others => '0');
                carry_reg     <= (others => '0');
                acc_sum_reg   <= (others => '0');
                acc_carry_reg <= '0';
                en_reg        <= '0';
            else
                en_reg <= en;

                if load_w = '1' then
                    w_reg <= w_in;
                end if;

                if en = '1' then
                    sum_reg       <= next_sum;
                    carry_reg     <= next_carry;
                    acc_sum_reg   <= next_acc_sum;
                    acc_carry_reg <= next_acc_carry;
                end if;
            end if;
        end if;
    end process;

    process(all)

        type stage_array is array(0 to INPUT_DATA_RADIX) of
            std_logic_vector(DATA_WIDTH-1 downto 0);

        variable s_stage : stage_array;  
        variable c_stage : stage_array;  

        variable a_vec   : std_logic_vector(DATA_WIDTH-1 downto 0); 
        variable b_vec   : std_logic_vector(DATA_WIDTH-1 downto 0);

        variable lsb     : std_logic_vector(INPUT_DATA_RADIX-1 downto 0); 

        variable acc_c   : std_logic_vector(INPUT_DATA_RADIX downto 0);

    begin

        lsb := (others => '0');

        if start = '1' then
            s_stage(0) := (others => '0');
            c_stage(0) := (others => '0');
        else
            s_stage(0) := sum_reg;
            c_stage(0) := carry_reg;
        end if;

        for step in 0 to INPUT_DATA_RADIX-1 loop

            for i in 0 to DATA_WIDTH-1 loop
                a_vec(i) := w_reg(i) and x_in(step);
            end loop;


            b_vec(DATA_WIDTH-1) := '0';
            for i in 0 to DATA_WIDTH-2 loop
                b_vec(i) := s_stage(step)(i+1);
            end loop;

            for i in 0 to DATA_WIDTH-1 loop
                s_stage(step+1)(i) := a_vec(i) xor b_vec(i) xor c_stage(step)(i);
                c_stage(step+1)(i) := (a_vec(i) and b_vec(i)) or
                                      (c_stage(step)(i) and (a_vec(i) xor b_vec(i)));
            end loop;

            lsb(step) := s_stage(step+1)(0);

        end loop;


        next_sum   <= s_stage(INPUT_DATA_RADIX);
        next_carry <= c_stage(INPUT_DATA_RADIX);

        if start = '1' then
            acc_c(0) := '0';
        else
            acc_c(0) := acc_carry_reg;
        end if;

        for i in 0 to INPUT_DATA_RADIX-1 loop
            next_acc_sum(i) <= lsb(i) xor y_in(i) xor acc_c(i);
            acc_c(i+1)     := (lsb(i) and y_in(i)) or
                              (acc_c(i) and (lsb(i) xor y_in(i)));
        end loop;

        next_acc_carry <= acc_c(INPUT_DATA_RADIX);

    end process;

end architecture;