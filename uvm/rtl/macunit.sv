module macunit #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    en,
    input  logic                    load_w,
    input  logic                    start,
    input  logic [DATA_WIDTH-1:0]   w_in,
    input  logic                    x_in,
    input  logic                    y_in,
    output logic                    x_out,
    output logic                    y_out,
    output logic                    en_out
);

    logic [DATA_WIDTH-1:0] w_reg;
    logic [DATA_WIDTH-1:0] sum_reg;
    logic [DATA_WIDTH-1:0] carry_reg;
    logic                  acc_sum_reg;
    logic                  acc_carry_reg;
    logic                  en_reg;

    logic [DATA_WIDTH-1:0] next_sum;
    logic [DATA_WIDTH-1:0] next_carry;
    logic                  next_acc_sum;
    logic                  next_acc_carry;

    assign x_out  = x_in;
    assign y_out  = acc_sum_reg;
    assign en_out = en_reg;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            w_reg         <= '0;
            sum_reg       <= '0;
            carry_reg     <= '0;
            acc_sum_reg   <= 1'b0;
            acc_carry_reg <= 1'b0;
            en_reg        <= 1'b0;
        end
        else begin
            en_reg <= en;

            if (load_w) begin
                w_reg <= w_in;
            end

            if (en) begin
                sum_reg       <= next_sum;
                carry_reg     <= next_carry;
                acc_sum_reg   <= next_acc_sum;
                acc_carry_reg <= next_acc_carry;
            end
        end
    end

    // Combinational
    always_comb begin
        logic [DATA_WIDTH-1:0] a_vec;
        logic [DATA_WIDTH-1:0] b_vec;
        logic [DATA_WIDTH-1:0] cin_vec;
        logic [DATA_WIDTH-1:0] s_vec;
        logic [DATA_WIDTH-1:0] co_vec;

        logic [DATA_WIDTH-1:0] sum;
        logic [DATA_WIDTH-1:0] carry;
        logic                  acc_carry;
        logic                  acc_in_bit;

        a_vec      = '0;
        b_vec      = '0;
        cin_vec    = '0;
        s_vec      = '0;
        co_vec     = '0;
        sum        = '0;
        carry      = '0;
        acc_carry  = 1'b0;
        acc_in_bit = 1'b0;

        if (start) begin
            sum       = '0;
            carry     = '0;
            acc_carry = 1'b0;
        end
        else begin
            sum       = sum_reg;
            carry     = carry_reg;
            acc_carry = acc_carry_reg;
        end

        for (int i = 0; i < DATA_WIDTH; i++) begin
            a_vec[i] = w_reg[i] & x_in;
        end

        b_vec[DATA_WIDTH-1] = sum[DATA_WIDTH-1];

        for (int i = 0; i < DATA_WIDTH-1; i++) begin
            b_vec[i] = sum[i+1];
        end

        cin_vec = carry;

        for (int i = 0; i < DATA_WIDTH; i++) begin
            s_vec[i]  = a_vec[i] ^ b_vec[i] ^ cin_vec[i];
            co_vec[i] = (a_vec[i] & b_vec[i]) |
                        (cin_vec[i] & (a_vec[i] ^ b_vec[i]));
        end

        next_sum   = s_vec;
        next_carry = co_vec;

        acc_in_bit = s_vec[0];

        next_acc_sum   = acc_in_bit ^ y_in ^ acc_carry;
        next_acc_carry = (acc_in_bit & y_in) |
                         (acc_carry & (acc_in_bit ^ y_in));
    end

endmodule