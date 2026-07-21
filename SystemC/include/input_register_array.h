//============================================================================
// Author: 
// Date: 12-07-2025
// Description: Header file of Input Register Array module.
//              This module implements an input register array with configurable delay cycles. It behaves like a pipeline of flip-flops
//              that stores incoming input activation values and outputs them after a specified delay. This behavior is designed to support
//              staggered input feeding in systolic array architectures, such as feeding inputs diagonally across systolic array columns.
//============================================================================

#ifndef INPUT_REGISTER_ARRAY_H
#define INPUT_REGISTER_ARRAY_H

#include "systemc.h"
#include "config.h"
#include <deque>
#include <array>

using namespace std;


SC_MODULE(InputRegisterArray) {
    sc_in<bool> clk;
    sc_in<bool> reset;
    sc_in<sc_int<8>> data_in[MUX_INPUTS];
    sc_out<sc_int<8>> data_out[MUX_INPUTS];

    const unsigned fixed_delay;

    array<array<sc_int<8>, MAX_DELAY>, MUX_INPUTS> pipe;
    sc_uint<8> cur_delay;

    void process() {
        for(int k = 0; k < MUX_INPUTS; k++) {
            for(int d = 0; d < MAX_DELAY; d++) {
                pipe[k][d] = 0;
            }
            data_out[k].write(0);
        }
        cur_delay = 0;
        wait();

        while(true) {
            for(int k = 0; k < MUX_INPUTS; k++) {
                for(int d = MAX_DELAY - 1; d >= 1; d--) {
                    pipe[k][d] = pipe[k][d - 1];
                }
                pipe[k][0] = data_in[k].read();
            }
            for (int k = 0; k < MUX_INPUTS; ++k) {
                sc_int<8> v = (fixed_delay == 0) ? data_in[k].read() : pipe[k][fixed_delay - 1];
                data_out[k].write(v);
            }
            wait();
        }
    }


    SC_HAS_PROCESS(InputRegisterArray);
    InputRegisterArray(sc_module_name n, unsigned delay_cycles) : sc_module(n) , fixed_delay((delay_cycles > MAX_DELAY) ? MAX_DELAY : delay_cycles) {
        SC_CTHREAD(process, clk.pos());
        async_reset_signal_is(reset, true);
    }
};

#endif