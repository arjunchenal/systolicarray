//============================================================================
// Author:
// Date: 01-07-2025
// Description: Testbench file for the tight compression systolic array
//============================================================================

#include "systemc.h"
#include "systolic_array.h"
#include "controller.h"
#include "config.h"
#include "macunit.h"
#include "sram.h"
#include <random>
#include <iostream>
#include <ctime>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <map>
#include <vector>
#include <filesystem>
#include <set>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <regex>
#include <chrono>
#include "helper.h"

const int ROWS_A = 1;
const int COLS_A = 4;
const int ROWS_B = 4;
const int COLS_B = 3;
const int MUX_LANES = MUX_INPUTS;

SC_MODULE(TestbenchWeightStationary) {
    sc_signal<bool> clk;
    sc_signal<bool> reset;

    sc_signal<sc_int<32>> result[ROWS_B][COLS_B];
    sc_signal<bool> done_tile;

    // SRAM ports for Input SRAM
    sc_signal<bool> we_input, re_input;
    sc_signal<sc_uint<8>> addr_row_input, addr_col_input;
    sc_signal<sc_int<32>> din_input, dout_input;

    // SRAM ports for Weight SRAM
    sc_signal<bool> we_weight, re_weight;
    sc_signal<sc_uint<8>> addr_row_weight, addr_col_weight;
    sc_signal<sc_int<32>> din_weight, dout_weight;

    // SRAM ports for Input Index SRAM
    sc_signal<bool> we_input_index, re_input_index;
    sc_signal<sc_uint<8>> addr_row_input_index, addr_col_input_index;
    sc_signal<sc_int<32>> din_input_index, dout_input_index;

    // SRAM ports for Output SRAM
    sc_signal<bool> we_output, re_output;
    sc_signal<sc_uint<8>> addr_row_output, addr_col_output;
    sc_signal<sc_int<32>> din_output[32], dout_output;

    // SRAM instances
    SRAM<512, 512, 32, 1>* input_sram;
    SRAM<512, 512, 32, 1>* weight_sram;
    SRAM<512, 512, 32, 1>* input_index_sram;
    SRAM<512, 512, 32, 32>* output_sram;

    SystolicArray<ROWS_B, COLS_B>* systolic_array;
    Controller<ROWS_B, COLS_B>* controller;

    sc_signal<sc_int<8>> X_in[COLS_B][MUX_INPUTS];

    sc_signal<sc_uint<16>> rowsA_cfg, colsA_cfg;
    sc_signal<sc_uint<8>>  rowsB_eff_cfg, colsB_eff_cfg;
    sc_signal<bool> go;

    void generate_clock() {
        while (true) {
            clk.write(false); wait(5, SC_NS);
            clk.write(true);  wait(5, SC_NS);
        }
    }

    vector<vector<sc_int<8>>> generate_random_matrix(int rows, int cols) {
        int total = rows * cols;
        vector<sc_int<8>> pool(total);
        for (int i = 0; i < total; ++i) pool[i] = i + 1;
        std::random_shuffle(pool.begin(), pool.end());

        vector<vector<sc_int<8>>> mat(rows, vector<sc_int<8>>(cols));
        int index = 0;
        for (int i = 0; i < rows; ++i)
            for (int j = 0; j < cols; ++j)
                mat[i][j] = pool[index++];
        return mat;
    }

    vector<vector<sc_int<8>>> transpose(const vector<vector<sc_int<8>>> &mat) {
        if (mat.empty() || mat[0].empty()) return {};
        size_t rows = mat.size(), cols = mat[0].size();
        vector<vector<sc_int<8>>> t(cols, vector<sc_int<8>>(rows));
        for (size_t i = 0; i < rows; ++i)
            for (size_t j = 0; j < cols; ++j)
                t[j][i] = mat[i][j];
        return t;
    }

    void print_generated_matrix(const vector<vector<sc_int<8>>> &mat) {
        cout << "Generated matrix:" << endl;
        for (const auto& row : mat) {
            for (const auto& elem : row) cout << elem << " ";
            cout << endl;
        }
    }

    // vector<vector<sc_int<8>>> matA  = read_matrix<sc_int<8>>("C://Uni Bremen//Project//ITEM_TIGHT_COMPRESSION_SYSTOLIC_GIT//Tight_compression_systolic//python//X_int8.txt");
    // vector<vector<sc_int<8>>> matB  = read_matrix<sc_int<8>>("C://Uni Bremen//Project//ITEM_TIGHT_COMPRESSION_SYSTOLIC_GIT//Tight_compression_systolic//python//weights_int8.txt");
    // vector<vector<sc_int<8>>> input_index = read_matrix<sc_int<8>>("C://Uni Bremen//Project//ITEM_TIGHT_COMPRESSION_SYSTOLIC_GIT//Tight_compression_systolic//python//input_index.txt");
    // vector<vector<int>> group_id = read_groups("C://Uni Bremen//Project//ITEM_TIGHT_COMPRESSION_SYSTOLIC_GIT//Tight_compression_systolic//python//groups.txt");

    void stimulate() {
        go.write(false);


        // vector<vector<sc_int<8>>> matA = {{10,11,12,13}};
        // vector<vector<sc_int<8>>> matB = {{1,5,7}, {0,4,0},{2,3,8},{0,6,9}};
        // vector<vector<sc_int<8>>> input_index = {{0, 2, 3}, {0, 1, 0}, {0, 1, 3}, {0,2,3}};
        // vector<vector<int>> group_id = {{0,1}, {1,2}, {0,3}};
        cout << "Matrix A: \n" << endl;
        print_generated_matrix(matA);

        
        cout << "weights rows: " << matB.size() << ", cols[0]: " << (matB.empty()?0:matB[0].size()) << "\n";


        cout << "The weight matrix is : " << endl;
        for (size_t i = 0; i < matB.size(); i++) {
            for (size_t j = 0; j < matB[i].size(); j++) {
                cout << matB[i][j] << " ";
            }
            cout << endl;
        }
        cout << endl;

        cout << "The input matrix is : " << endl; 
        cout << "input_index rows: " << input_index.size() << ", cols[0]: " << (input_index.empty()?0:input_index[0].size()) << "\n";
        for (size_t i = 0; i < input_index.size(); i++) {
            for (size_t j = 0; j < input_index[i].size(); j++) {
                cout << input_index[i][j] << " ";
            }
            cout << endl;
        }
        cout << endl;

        cout << "The groups are : " << endl;
        for (size_t i = 0; i < group_id.size(); i++) {
            for (size_t j = 0; j < group_id[i].size(); j++) {
                cout << group_id[i][j] << " ";
            }
            cout << endl;
        }
        
        // Passing the input matrix, weight matrix and input_index matrix to controller

        const int HfB = (int)matB.size();                 
        const int GfB = HfB ? (int)matB[0].size() : 0;     
        const int HfI = (int)input_index.size();
        const int GfI = HfI ? (int)input_index[0].size() : 0;
        const int H = std::min(ROWS_B, std::min(HfB, HfI));  
        const int G = std::min(COLS_B, std::min(GfB, GfI)); 
        const bool B_is_HxG  = (HfB == H && GfB == G);
        const bool IDX_is_HxG= (HfI == H && GfI == G);


        //Inputs
        for(int i = 0; i < ROWS_A;i++) {
            for(int j = 0;j< COLS_A;j++) {
                cout << "the data is : " << matA[i][j] << endl;
                controller->preload_matA[i][j] = matA[i][j];
            }
        }
        cout << "The value of H is :L " << H << endl;
        cout << "The value of G is :L " << G << endl;


        for(int i = 0; i < H; i++) {
            for(int j = 0; j < G; j++) {
                controller->preload_matB[i][j] = matB[i][j];
                cout << "the data B is : " << matB[i][j] << endl;
                controller->preload_input_index_matrix[i][j] = input_index[i][j];
            }
        }

        for(int i=0;i<COLS_B;i++) {
            controller->group_size[i] = 0;
            for(int j = 0; j < MUX_INPUTS;j++) {
                controller->groups_map[i][j] = 0;
            }
        }

        const int group_eff = std::min<int>(G, (int)group_id.size());
        for (int g = 0; g < group_eff; ++g) {
            const int sz = std::min<int>((int)group_id[g].size(), MUX_LANES);
            controller->group_size[g] = (sc_uint<5>)sz;
            for (int l = 0; l < sz; ++l) {
                controller->groups_map[g][l] = (sc_uint<5>)group_id[g][l];
            }
        }

        rowsA_cfg.write(ROWS_A);
        colsA_cfg.write(COLS_A);
        rowsB_eff_cfg.write((sc_uint<8>)H);  
        colsB_eff_cfg.write((sc_uint<8>)group_eff);

    
        reset.write(true);  
        wait(20, SC_NS);
        reset.write(false); 
        wait(20, SC_NS);
    }


    SC_CTOR(TestbenchWeightStationary) {
        input_sram = new SRAM<512, 512, 32, 1>("input_sram");
        input_sram->clk(clk);
        input_sram->we(we_input);
        input_sram->re(re_input);
        input_sram->addr_row(addr_row_input);
        input_sram->addr_col(addr_col_input);
        input_sram->din[0](din_input);
        input_sram->dout(dout_input);

        weight_sram = new SRAM<512, 512, 32, 1>("weight_sram");
        weight_sram->clk(clk);
        weight_sram->we(we_weight);
        weight_sram->re(re_weight);
        weight_sram->addr_row(addr_row_weight);
        weight_sram->addr_col(addr_col_weight);
        weight_sram->din[0](din_weight);
        weight_sram->dout(dout_weight);

        input_index_sram = new SRAM<512, 512, 32, 1>("input_index_sram");
        input_index_sram->clk(clk);
        input_index_sram->we(we_input_index);
        input_index_sram->re(re_input_index);
        input_index_sram->addr_row(addr_row_input_index);  
        input_index_sram->addr_col(addr_col_input_index);
        input_index_sram->din[0](din_input_index);
        input_index_sram->dout(dout_input_index);

        output_sram = new SRAM<512, 512, 32, 32>("output_sram");
        output_sram->clk(clk);
        output_sram->we(we_output);
        output_sram->re(re_output);
        output_sram->addr_row(addr_row_output);
        output_sram->addr_col(addr_col_output);
        for (int i = 0; i < 32; i++) output_sram->din[i](din_output[i]);
        output_sram->dout(dout_output);

        systolic_array = new SystolicArray<ROWS_B, COLS_B>("systolic_array");
        systolic_array->clk(clk);
        systolic_array->reset(reset);
        for (int i = 0; i < COLS_B; i++)
            for (int k = 0; k < MUX_INPUTS; k++) {
                X_in[i][k].write(0);
                systolic_array->X_in[i][k](X_in[i][k]);
            }
        for (int i = 0; i < ROWS_B; i++)
            for (int j = 0; j < COLS_B; j++)
                systolic_array->result[i][j](result[i][j]);

        controller = new Controller<ROWS_B, COLS_B>("controller", X_in);
        controller->clk(clk);
        controller->reset(reset);
        controller->systolic_array = systolic_array;
        controller->done_tile(done_tile);

        controller->rowsA_cfg(rowsA_cfg);
        controller->colsA_cfg(colsA_cfg);
        controller->rowsB_eff_cfg(rowsB_eff_cfg);
        controller->colsB_eff_cfg(colsB_eff_cfg);
        controller->go(go);

        // Connect Controller to SRAM ports
        controller->we_input(we_input);
        controller->re_input(re_input);
        controller->addr_row_input(addr_row_input);
        controller->addr_col_input(addr_col_input);
        controller->din_input(din_input);
        controller->dout_input(dout_input);

        controller->we_weight(we_weight);
        controller->re_weight(re_weight);
        controller->addr_row_weight(addr_row_weight);
        controller->addr_col_weight(addr_col_weight);
        controller->din_weight(din_weight);
        controller->dout_weight(dout_weight);

        controller->we_input_index(we_input_index);
        controller->re_input_index(re_input_index);
        controller->addr_row_input_index(addr_row_input_index);
        controller->addr_col_input_index(addr_col_input_index);
        controller->din_input_index(din_input_index);
        controller->dout_input_index(dout_input_index);

        controller->we_output(we_output);
        controller->re_output(re_output);
        controller->addr_row_output(addr_row_output);
        controller->addr_col_output(addr_col_output);
        for (int i = 0; i < 32; i++) controller->din_output[i](din_output[i]);
        controller->dout_output(dout_output);

        SC_THREAD(generate_clock);
        SC_THREAD(stimulate);
    }

    ~TestbenchWeightStationary() {
        delete systolic_array;
        delete controller;
        delete input_sram;
        delete weight_sram;
        delete output_sram;
    }
};

int sc_main(int argc, char* argv[]) {
    srand(time(NULL));
    TestbenchWeightStationary tb("tb_weight");

    sc_trace_file* tf = sc_create_vcd_trace_file("trace_weightstationary");
    tf->set_time_unit(1, SC_NS);

    sc_trace(tf, tb.clk, "clk");
    sc_trace(tf, tb.reset, "reset");
    sc_trace(tf, tb.done_tile, "done_tile");
    sc_trace(tf, tb.go, "go");

    // Input
    sc_trace(tf, tb.we_input, "input_sram_we");
    sc_trace(tf, tb.re_input, "input_sram_re");
    sc_trace(tf, tb.addr_row_input, "input_sram_addr_row");
    sc_trace(tf, tb.addr_col_input, "input_sram_addr_col");
    sc_trace(tf, tb.din_input, "input_sram_din");
    sc_trace(tf, tb.dout_input, "input_sram_dout");

    // Weights
    sc_trace(tf, tb.we_weight, "weight_sram_we");
    sc_trace(tf, tb.re_weight, "weight_sram_re");
    sc_trace(tf, tb.addr_row_weight, "weight_sram_addr_row");
    sc_trace(tf, tb.addr_col_weight, "weight_sram_addr_col");
    sc_trace(tf, tb.din_weight, "weight_sram_din");
    sc_trace(tf, tb.dout_weight, "weight_sram_dout");

    // Input Index
    sc_trace(tf, tb.we_input_index, "input_index_sram_we");
    sc_trace(tf, tb.re_input_index, "input_index_sram_re");
    sc_trace(tf, tb.addr_row_input_index, "input_index_sram_addr_row");
    sc_trace(tf, tb.addr_col_input_index, "input_index_sram_addr_col");
    sc_trace(tf, tb.din_input_index, "input_index_sram_din");
    sc_trace(tf, tb.dout_input_index, "input_index_sram_dout");

    // Output
    sc_trace(tf, tb.we_output, "output_sram_we");
    sc_trace(tf, tb.re_output, "output_sram_re");
    sc_trace(tf, tb.addr_row_output, "output_sram_addr_row");
    sc_trace(tf, tb.addr_col_output, "output_sram_addr_col");
    for (int i = 0; i < 32; i++) {
        std::ostringstream name; name << "output_sram_din_" << i;
        sc_trace(tf, tb.din_output[i], name.str());
    }
    sc_trace(tf, tb.dout_output, "output_sram_dout");

    for (int i = 0; i < ROWS_B; i++)
        for (int j = 0; j < COLS_B; j++)
            sc_trace(tf, tb.systolic_array->partial_sum_sig[i][j],
                     "partial_sum_PE_" + std::to_string(i) + "_" + std::to_string(j));

    for (int col = 0; col < COLS_B; col++)
        for (int k = 0; k < MUX_INPUTS; k++)
            sc_trace(tf, tb.X_in[col][k],
                     "X_in_" + std::to_string(col) + "_mux_" + std::to_string(k));

    for (int r = 0; r < ROWS_B; ++r)
        sc_trace(tf,
            tb.systolic_array->partial_sum_sig[r][COLS_B - 1],  
            "psum_row" + std::to_string(r) + "_rightmost");

    sc_start(1000000, SC_NS);
    sc_close_vcd_trace_file(tf);
    return 0;
}




























