//============================================================================
// Author      :  
// Date        : 01-07-2025
// Description : Implementation of the MAC Unit (Weighted-Stationary) module.
//
//               This module performs multiply-accumulate (MAC) operations 
//               using an 8-bit signed input activation and a fixed 8-bit 
//               weight (set via set_weight()). It streams input X values 
//               while keeping the weight stationary.
//
//               Internally:
//               - ALU performs 8x8-bit multiplication to produce a 16-bit result.
//               - Accumulator sums the 16-bit ALU output with a 32-bit partial sum.
//               - Supports reset and clear functionality for accumulator control.
//
//               Outputs:
//               - Updated partial sum (32-bit)
//               - Forwarded input X value for horizontal streaming
//               - Result signal for monitoring MAC output
//============================================================================


#ifndef MacUnit_H
#define MacUnit_H

#include "systemc.h"
#include "alu.h"
#include "accumulator.h"
#include "config.h"
#include <vector>



SC_MODULE(MacUnit) {
    sc_in<bool> clk;                        // Clock
    sc_in<bool> reset;                      // Reset

    sc_in<sc_int<32>> partial_sum_in;       // Partial sum in from left
    sc_out<sc_int<32>> partial_sum_out;     // partial sum out to right

    sc_out<sc_int<32>> result;              // For the result value of the current PE

    sc_in<sc_uint<4>> mux_sel;              // Select signal to pick one out 16 input values coming to PE
    sc_in<sc_int<8>> X_in[MUX_INPUTS];      // Input lines of MUX (16 inputs at time)
    sc_out<sc_int<8>> X_out[MUX_INPUTS];    // For passing 16 inputs to upward PE

    sc_signal<sc_int<8>> X_sig, Y_sig;      // Internal signal to ALU
    sc_signal<sc_int<16>> alu_out_sig;      // ALU Product
    sc_signal<bool> clear_sig;              // accumulator clear

    sc_int<8> weight;                       // Holds weight for this PE
    sc_uint<4> input_index;                 // For storing the index value from address LUT which is used to pick input line from MUX

    ALU alu;            // ALU module               
    Accumulator acc;    // Accumulator module

    void process();
    void set_weight(sc_int<8> w);
    void set_input_index(sc_uint<4> id_index);


    SC_CTOR(MacUnit) : alu("alu"), acc("acc"){
        alu.X(X_sig);
        alu.Y(Y_sig);
        alu.result(alu_out_sig);
        alu.clk(clk);

        acc.alu_result(alu_out_sig);
        acc.acc_in(partial_sum_in);
        acc.acc_out(partial_sum_out);
        acc.reset(reset);
        acc.clk(clk);
        acc.clear(clear_sig);

        SC_CTHREAD(process, clk.pos());
        async_reset_signal_is(reset, true);
    }
};

#endif