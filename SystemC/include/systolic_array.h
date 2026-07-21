//============================================================================
// Author:  
// Date: 12-07-2025
// Description: Header file of Systolic array module.
//              This module performs signed 8-bit multiplication of inputs X and Y and produces 16-bit signed result.
//              It operates synchronously on the positive edge of the clock signal. The ALU is main element computational
//              element used in the systolic array based architecture.
//============================================================================

#ifndef SYSTOLIC_ARRAY_H
#define SYSTOLIC_ARRAY_H

#include "systemc.h"
#include "macunit.h"
#include "config.h"
#include <iostream>

using namespace std;
template <int ROWS_B, int COLS_B>
SC_MODULE(SystolicArray) {
    sc_in<bool> clk;
    sc_in<bool> reset;
    sc_in<sc_int<8>> X_in[COLS_B][MUX_INPUTS];

    sc_out<sc_int<32>> result[ROWS_B][COLS_B];

    MacUnit* mac_array[ROWS_B][COLS_B];

    sc_signal<sc_int<8>> X_in_buffer[COLS_B][MUX_INPUTS];
    sc_signal<sc_int<8>> X_intermodule_sig[ROWS_B][COLS_B][MUX_INPUTS];         // Vertical propogation of input activations
    sc_signal<sc_int<32>> partial_sum_sig[ROWS_B][COLS_B];
    sc_signal<sc_int<32>> zero_sig;

    sc_signal<sc_uint<4>> mux_sel[ROWS_B][COLS_B];      

    int cycle_count = 0;

    void set_weight(int row, int col, sc_int<8> weight) {
        if (row >= 0 && row < ROWS_B && col >= 0 && col < COLS_B) {
            mac_array[row][col]->set_weight(weight);
        }
    }

    void set_input_index(int row, int col, sc_uint<4> input_index) {
        if(row >= 0 && row < ROWS_B && col >= 0 && col < COLS_B) {
            mac_array[row][col]->set_input_index(input_index);
            mux_sel[row][col].write(input_index);
        }
    }

    void propagate_inputs_vertically() {
        for (int j = 0; j < COLS_B; ++j) {
            for(int k = 0; k < MUX_INPUTS; k++) {
                X_in_buffer[j][k].write(X_in[j][k].read());
            }
        }
    }

    SC_CTOR(SystolicArray) {
        zero_sig.write(0);

        for(int i = 0; i < ROWS_B; i++) {
            for(int j = 0; j < COLS_B; j++) {
                string name = "mac_" + to_string(i) + "_" + to_string(j);

                mac_array[i][j] = new MacUnit(name.c_str());
                mac_array[i][j]->clk(clk);
                mac_array[i][j]->reset(reset);

                mac_array[i][j]->mux_sel(mux_sel[i][j]);

                for (int k = 0; k < MUX_INPUTS; ++k) {
                    if (i == 0) {
                        mac_array[i][j]->X_in[k](X_in_buffer[j][k]);
                    } else {
                        mac_array[i][j]->X_in[k](X_intermodule_sig[i - 1][j][k]);
                    }
                    mac_array[i][j]->X_out[k](X_intermodule_sig[i][j][k]);
                }

                if(j == 0) {
                    mac_array[i][j]->partial_sum_in(zero_sig);
                } else {
                    mac_array[i][j]->partial_sum_in(partial_sum_sig[i][j-1]);
                }
                mac_array[i][j]->partial_sum_out(partial_sum_sig[i][j]);
                mac_array[i][j]->result(result[i][j]);
            
            }
        }

        SC_METHOD(propagate_inputs_vertically);
        for (int j = 0; j < COLS_B; ++j) {
            for(int k = 0; k < MUX_INPUTS; k++) {
                sensitive << X_in[j][k];
            }
        }

    }

    ~SystolicArray() {
        for (int i = 0; i < ROWS_B; i++)
            for (int j = 0; j < COLS_B; j++)
                delete mac_array[i][j];

    }
};

#endif

