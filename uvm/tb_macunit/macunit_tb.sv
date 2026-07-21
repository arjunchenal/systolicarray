`timescale 1ns/1ns

`include "uvm_macros.svh"
import uvm_pkg::*;
import macunit_pkg::*;

module top;

    logic clk;

    // DUT
    macunit dut (
        .clk(intf.clk),
        .rst(intf.rst),
        .en(intf.en),
        .load_w(intf.load_w),
        .start(intf.start),
        .w_in(intf.w_in),
        .x_in(intf.x_in),
        .y_in(intf.y_in),
        .x_out(intf.x_out),
        .y_out(intf.y_out),
        .en_out(intf.en_out)
    );

    macunit_intf intf(.clk(clk));   // interface from dut and tb

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        uvm_config_db#(virtual macunit_intf)::set(null, "*", "vif", intf);
        run_test("macunit_test");
    end

endmodule