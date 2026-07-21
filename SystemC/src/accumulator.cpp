//===========================================================================
// Author      : 
// Date        : 01-07-2025
// Description : Implementation of the Accumulator module.
//
//               This module accumulates the result from the ALU (16-bit)
//               with the incoming accumulation input (32-bit) to produce
//               a new 32-bit accumulated output. The process runs on the
//               positive edge of the clock using SystemC CTHREAD.
//
//               - If reset is asserted, the accumulator is cleared to zero.
//               - Otherwise, it adds alu_result and acc_in and updates the 
//                 output.
//
//============================================================================

#include "accumulator.h"

void Accumulator::update_acc() {
    acc_out.write(0);
    wait();
    while (true) {
        if (clear.read()) {
            accumulator = 0;
            acc_out.write(0);
        } 
        else {
            sc_int<32> sum = acc_in.read() + (sc_int<32>) alu_result.read();
            accumulator = sum;
            acc_out.write(sum);
        }
        wait();
    }
}


