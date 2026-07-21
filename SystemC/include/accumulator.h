//============================================================================
// Author      :  
// Date        : 01-07-2025
// Description : Implementation of the Accumulator module.
//
//              This module performs accumulation of 16-bit ALU output
//              into a 32-bit accumulator register. It supports synchronous
//              reset and clear control signals.
//
//              - On each positive clock edge, if reset is asserted, the
//                accumulator is set to zero.
//              - If clear is high (and reset is not), the accumulator is
//                cleared before accumulation.
//              - Otherwise, it accumulates the input from the ALU along
//               with the incoming accumulation value.
//
//              The result is output as a 32-bit signed value.
//============================================================================


#ifndef ACCUMULATOR_H
#define ACCUMULATOR_H

#include "systemc.h"

SC_MODULE(Accumulator) {
    sc_in<sc_int<16>> alu_result;
    sc_in<sc_int<32>> acc_in; 
    sc_in<bool> clk;
    sc_out<sc_int<32>> acc_out;
    sc_int<32> accumulator; 
    sc_in<bool> clear;
    sc_in<bool> reset;
    
    void update_acc(); 

    SC_CTOR(Accumulator) {
        accumulator = 0;
        SC_CTHREAD(update_acc, clk.pos());
        async_reset_signal_is(reset, true);   
    }
};

#endif 