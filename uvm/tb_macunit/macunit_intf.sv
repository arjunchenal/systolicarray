interface macunit_intf(input logic clk);
    logic rst;
    logic en;
    logic load_w;
    logic start;
    logic [7:0] w_in;
    logic x_in;
    logic y_in;
    logic x_out;
    logic y_out;
    logic en_out;

endinterface