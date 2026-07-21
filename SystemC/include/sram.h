//============================================================================
// Author: 
// Date: 01-07-2025
// Description: Header and implementation of a parameterized SRAM module.
//              This module simulates synchronous SRAM behavior for use in 
//              systolic array architectures. It supports configurable dimensions 
//              and data width, and handles both read and write operations based 
//              on clocked control signals.
//
//              - `we`: Write Enable — when high, writes `din` to specified address.
//              - `re`: Read Enable — when high, reads from specified address into `dout`.
//              - Addressing is based on row and column indices.
//              - Data is stored in a 2D array `mem[ROWS][COLS]`.
//
//              Intended for storing:
//              - Input activations
//              - Weight tiles (compressed or dense)
//              - Output results
//============================================================================

#ifndef SRAM_H
#define SRAM_H

#include "systemc.h"

template<int ROWS, int COLS, int DATA_WIDTH = 32, int PARALLEL_WRITE = 1>
SC_MODULE(SRAM) {
    // Ports
    sc_in<bool> clk;
    sc_in<bool> we;                         // Write enable
    sc_in<bool> re;                         // Read enable
    sc_in<sc_uint<8>> addr_row;             // Row address
    sc_in<sc_uint<8>> addr_col;             // Column address
    sc_in<sc_int<DATA_WIDTH>> din[PARALLEL_WRITE];      // Data input
    sc_out<sc_int<DATA_WIDTH>> dout;        // Data output

    sc_int<DATA_WIDTH> mem[ROWS][COLS];

    void process() {
        if (we.read()) {
            if (PARALLEL_WRITE == 1) {
                int row = addr_row.read();
                int col = addr_col.read();
                if (row < ROWS && col < COLS) {
                    mem[row][col] = din[0].read();
                    cout << "[SRAM] WRITE: mem[" << row << "][" << col << "] = " << din[0].read() << endl;
                } else {
                    cerr << "[SRAM] Write Error: Address out of bounds" << endl;
                }
            } else {
                for (int i = 0; i < PARALLEL_WRITE; ++i) {
                    int row = addr_row.read();
                    int col = addr_col.read() + i;
                    if (row < ROWS && col < COLS) {
                        mem[row][col] = din[i].read();
                        cout << "[SRAM] WRITE: mem[" << row << "][" << col << "] = " << din[i].read() << endl;
                    } else {
                        cerr << "[SRAM] Write Error: Address out of bounds at col = " << col << endl;
                    }
                }
            }
        }

        if (re.read()) {
            if (addr_row.read() < ROWS && addr_col.read() < COLS) {
                dout.write(mem[addr_row.read()][addr_col.read()]);
                cout << "[SRAM] READ: mem[" << addr_row.read() << "][" << addr_col.read() << "] = " << mem[addr_row.read()][addr_col.read()] << endl;
            } else {
                cerr << "[SRAM] Read Error: Address out of bounds" << endl;
                dout.write(0);
            }
        }
    }

    SC_CTOR(SRAM) {
        SC_METHOD(process);
        sensitive << clk.pos();
        for (int i = 0; i < ROWS; ++i)
            for (int j = 0; j < COLS; ++j)
                mem[i][j] = 0;
    }
};

#endif





