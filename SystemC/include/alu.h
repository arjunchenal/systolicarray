//============================================================================
// Author: 
// Date: 01-07-2025
// Description: Header file of ALU module.
//              This module performs signed 8-bit multiplication of inputs X and Y and produces 16-bit signed result.
//              It operates synchronously on the positive edge of the clock signal. The ALU is main element computational
//              element used in the systolic array based architecture.
//============================================================================



#ifndef ALU_H
#define ALU_H

#include "systemc.h"

SC_MODULE(ALU) {
    sc_in<sc_int<8>> X, Y;
    sc_out<sc_int<16>> result;
    sc_in<bool> clk;

    void multiply();

    SC_CTOR(ALU) {
        SC_CTHREAD(multiply, clk.pos());
    }
};

#endif
