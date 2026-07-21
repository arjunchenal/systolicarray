library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity macunit_serial is
    generic (
        DATA_WIDTH : positive := 8
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        en     : in  std_logic;
        load_w : in  std_logic;
        start  : in  std_logic;
        w_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        x_in   : in  std_logic;
        y_in   : in  std_logic;
        x_out  : out std_logic;
        y_out  : out std_logic;
        en_out : out std_logic
    );
end entity;

architecture rtl of macunit_serial is
    signal w_reg         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sum_reg       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal carry_reg     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal acc_sum_reg   : std_logic;
    signal acc_carry_reg : std_logic;
    signal en_reg        : std_logic;

    signal next_sum       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal next_carry     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal next_acc_sum   : std_logic;
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
                acc_sum_reg   <= '0';
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
        variable a_vec         : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable b_vec         : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable cin_vec       : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable s_vec         : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable co_vec        : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable sum       : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable carry     : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable acc_carry : std_logic;
        variable acc_in_bit    : std_logic;
    begin
        a_vec         := (others => '0');
        b_vec         := (others => '0');
        cin_vec       := (others => '0');
        s_vec         := (others => '0');
        co_vec        := (others => '0');
        sum       := (others => '0');
        carry     := (others => '0');
        acc_carry := '0';
        acc_in_bit    := '0';

        if start = '1' then
            sum       := (others => '0');
            carry     := (others => '0');
            acc_carry := '0';
        else
            sum       := sum_reg;
            carry     := carry_reg;
            acc_carry := acc_carry_reg;
        end if;

        for i in 0 to DATA_WIDTH-1 loop
            a_vec(i) := w_reg(i) and x_in;
        end loop;

        b_vec(DATA_WIDTH-1) := sum(DATA_WIDTH-1);
        for i in 0 to DATA_WIDTH-2 loop
            b_vec(i) := sum(i+1);
        end loop;

        cin_vec := carry;

        for i in 0 to DATA_WIDTH-1 loop
            s_vec(i)  := a_vec(i) xor b_vec(i) xor cin_vec(i);
            co_vec(i) := (a_vec(i) and b_vec(i)) or
                         (cin_vec(i) and (a_vec(i) xor b_vec(i)));
        end loop;

        next_sum   <= s_vec;
        next_carry <= co_vec;
        acc_in_bit := s_vec(0);
        next_acc_sum <= acc_in_bit xor y_in xor acc_carry;
        next_acc_carry <= (acc_in_bit and y_in) or (acc_carry and (acc_in_bit xor y_in));
    end process;

end architecture;