#ifndef CONTROLLER_H
#define CONTROLLER_H

#include "systemc.h"
#include "sram.h"
#include "systolic_array.h"
#include "input_register_array.h"
#include "config.h"
#include <iostream>
#include <string>
#include <utility>

using namespace std;

template<int RowsB, int ColsB>
SC_MODULE(Controller) {
    sc_in<bool> clk;
    sc_in<bool> reset;
    
    // For Input SRAM
    sc_out<bool> we_input, re_input;
    sc_out<sc_uint<8>> addr_row_input, addr_col_input;
    sc_out<sc_int<32>> din_input;
    sc_in<sc_int<32>> dout_input;

    // For Weight SRAM
    sc_out<bool> we_weight, re_weight;
    sc_out<sc_uint<8>> addr_row_weight, addr_col_weight;
    sc_out<sc_int<32>> din_weight;
    sc_in<sc_int<32>> dout_weight;

    // For Input Index SRAM
    sc_out<bool> we_input_index, re_input_index;
    sc_out<sc_uint<8>> addr_row_input_index, addr_col_input_index;
    sc_out<sc_int<32>> din_input_index;
    sc_in<sc_int<32>> dout_input_index;

    // For Output SRAM
    sc_out<bool> we_output, re_output;
    sc_out<sc_uint<8>> addr_row_output, addr_col_output;
    sc_out<sc_int<32>> din_output[32];
    sc_in<sc_int<32>> dout_output;

    SystolicArray<RowsB, ColsB>* systolic_array;
    sc_signal<sc_int<8>> (&X_in_sig)[ColsB][MUX_INPUTS];
    sc_signal<sc_int<8>> input_pipeline_data_in[ColsB][MUX_INPUTS];
    sc_signal<sc_int<8>> input_pipeline_data_out[ColsB][MUX_INPUTS];
    InputRegisterArray* input_pipeline[ColsB];

    // Internal buffers
    sc_int<8> input_buffer[2][ColsB][MAX_ROWS_A];
    sc_int<8> preload_matB[ColsB][RowsB];
    sc_int<8> preload_input_index_matrix[ColsB][RowsB];

    sc_int<8> preload_matA[MAX_ROWS_A][MAX_COLS_A];
    sc_int<8> preload_matA2[MAX_ROWS_A][MAX_COLS_A];

    int preload_input_tile_index, preload_weight_tile_index, total_input_tiles, active_buffer;
    int preload_buffer, rowsA, colsA, compute_cycle, input_flow_counter, capture_tile_id;
    int output_tile_counter, flush_counter, current_column; 

    sc_out<bool> done_tile;
    sc_signal<bool> start;
    sc_signal<bool> stream_enable;

    bool more_tiles_available, isWriteReady, fsm_tile_complete, write_back_complete;
    int  tile_input_start_cycle, current_tile;

    static const int MAX_TILES = (MAX_COLS_A + ColsB - 1) / ColsB;
    int  tile_flow_counter[MAX_TILES];
    bool tile_capture_done[MAX_TILES];
    int  tile_compute_counters[MAX_TILES];

    int tile_rowsA, tile_colsB;     
    bool preload_buffer_ready, weight_preload_done, input_preload_done;

    sc_in<sc_uint<8>> rowsB_eff_cfg, colsB_eff_cfg;  
    sc_signal<sc_uint<8>> rowsB_eff, colsB_eff;

    sc_in<sc_uint<16>> rowsA_cfg, colsA_cfg;     

    sc_int<32> output_line[32];
    int         cap_t;
    int         cap_row;
    bool        capturing;

    sc_signal<bool> start_weight_preload_sig, start_input_preload_sig;
    sc_signal<bool> weight_preload_done_sig, input_preload_done_sig;

    enum State { IDLE, PRELOAD_CFG, WAIT_CFG, COMPUTE, FLUSH, NEXT_TILE, DONE };
    State current_state;

    bool preload_done_once;

    sc_in<bool> go;
    bool stream_row_done;   // set when a row completes its slots + flush
    bool all_rows_done;     // set when cur_m == rowsA

    int lane_map_col[ColsB][MUX_INPUTS];

    int cur_m;
    int cur_k;

    int slot_t;                 // 0..S_MAX-1
    int S_MAX;                  // max group size across columns

    sc_uint<5> groups_map[ColsB][MUX_INPUTS];  // groups_map[col][lane] = k
    sc_uint<5> group_size[ColsB];              // 1 or 2 lanes per compressed column


    bool inject_phase;


    static constexpr int PIPE_LAT = 0;
    inline int flush_len() const {
        return (int)colsB_eff.read().to_uint() - 1 + PIPE_LAT;
    }
    static constexpr int RIGHT_COL = ColsB - 1;  // used if you re-enable capture

    inline int ceil_div_int(int a, int b) { return (a + b - 1) / b; }

    inline sc_int<32> get_partial_sum(int row, int col) {
        return systolic_array->partial_sum_sig[row][col].read();
    }

    void do_reset() {
        preload_done_once = false;
        preload_input_tile_index = 0;
        preload_weight_tile_index = 0;
        total_input_tiles = 1;
        active_buffer = 0;
        preload_buffer = 1;
        rowsA = 0; colsA = 0;

        current_state = IDLE;

        compute_cycle = 0;
        input_flow_counter = 0;
        capture_tile_id = 0;
        output_tile_counter = 0;
        flush_counter = 0;
        current_column = 0;

        done_tile.write(false);
        start.write(false);
        stream_enable.write(false);

        more_tiles_available = false;
        isWriteReady = false;
        fsm_tile_complete = false;
        write_back_complete = false;
        tile_input_start_cycle = 0;

        current_tile = 0;

        inject_phase = false;   // not injecting yet


        cur_m = 0;
        cur_k = 0;
        slot_t = 0;    
        stream_row_done = false;
        all_rows_done   = false;


        for (int i = 0; i < MAX_TILES; ++i) {
            tile_flow_counter[i] = 0;
            tile_capture_done[i] = true;
            tile_compute_counters[i] = -1;
        }

        tile_rowsA = 0;
        tile_colsB = ColsB;
        preload_buffer_ready = false;
        weight_preload_done = false;
        input_preload_done = false;

        rowsB_eff.write( (sc_uint<8>) RowsB );
        colsB_eff.write( (sc_uint<8>) ColsB );

        for (int b = 0; b < 2; b++)
            for (int c = 0; c < ColsB; c++)
                for (int r = 0; r < MAX_ROWS_A; r++)
                    input_buffer[b][c][r] = 0;

        for(int i=0;i<32;i++) output_line[i]=0;
        cap_t = 0;
        cap_row = 0;
        capturing = false;

        start_weight_preload_sig.write(false);
        start_input_preload_sig.write(false);

        for (int j = 0; j < ColsB; ++j)
            for (int l = 0; l < MUX_INPUTS; ++l)
                lane_map_col[j][l] = -1;

    }

    void rebuild_lane_map_from_groups() {
        S_MAX = 1;
    }

    void preload_weights_cfg_() {
        const int r_eff = rowsB_eff.read().to_uint();  
        const int c_eff = colsB_eff.read().to_uint(); 

        for (int i = 0; i < r_eff; ++i) {       
            for (int j = 0; j < c_eff; ++j) {     
                sc_int<8> w = preload_matB[i][j];                 
                int       k = (int)preload_input_index_matrix[i][j]; 

                int sz = (int)group_size[j];
                if (sz > MUX_INPUTS) sz = MUX_INPUTS;   

                sc_uint<4> lane_sel = 0; 
                bool matched = false;
                for (int l = 0; l < sz; ++l) {
                    if (k == (int)groups_map[j][l]) { 
                        lane_sel = (sc_uint<4>)l;
                        matched  = true;
                        break;
                    }
                }
                if (!matched && k >= 0 && k < sz) {
                    lane_sel = (sc_uint<4>)k;
                }

                addr_row_weight.write(i);
                addr_col_weight.write(j);
                addr_row_input_index.write(i);
                addr_col_input_index.write(j);
                din_weight.write((sc_int<32>)w);
                din_input_index.write((sc_int<32>)lane_sel); 
                we_weight.write(true);
                re_weight.write(false);
                we_input_index.write(true);
                re_input_index.write(false);
                wait();
                we_weight.write(false);
                we_input_index.write(false);

                din_weight.write(0);
                din_input_index.write(0);
                addr_row_weight.write(0);
                addr_col_weight.write(0);
                addr_row_input_index.write(0);
                addr_col_input_index.write(0);

                if (systolic_array) {
                    systolic_array->set_weight(i, j, w);
                    systolic_array->set_input_index(i, j, lane_sel);
                }
            }
        }
    }



    // void preload_weights_cfg_() {
    //     const sc_uint<8> r_eff = rowsB_eff.read();
    //     const sc_uint<8> c_eff = colsB_eff.read();

    //     cout << " the value of r_eff from controller :  " << r_eff << endl;
    //     cout << " the value of c_eff from controller :  " << c_eff << endl;

    //     for (int i = 0; i < r_eff; i++) {
    //         for (int j = 0; j < c_eff; j++) {
    //             sc_int<8>  w  =  preload_matB[i][j];

    //             cout << "the value is : " << preload_matB[i][j] << endl;


    //             sc_int<8> ip_index = preload_input_index_matrix[i][j];

    //             addr_row_weight.write(i);
    //             addr_col_weight.write(j);
    //             addr_row_input_index.write(i);
    //             addr_col_input_index.write(j);
    //             din_weight.write((sc_int<32>)w);
    //             din_input_index.write((sc_int<32>)ip_index);
    //             we_weight.write(true);
    //             re_weight.write(false);
    //             we_input_index.write(true);
    //             re_input_index.write(false);
    //             wait(); 
    //             we_weight.write(false);
    //             we_input_index.write(false);

    //             din_weight.write(0);
    //             din_input_index.write(0);
    //             addr_row_weight.write(0);
    //             addr_col_weight.write(0);
    //             addr_row_input_index.write(0);
    //             addr_col_input_index.write(0);

    //             if (systolic_array) {
    //                 systolic_array->set_weight(i, j, w);
    //                 if (ip_index >= 0 && ip_index < MUX_INPUTS)
    //                     systolic_array->set_input_index(i, j, sc_uint<4>(ip_index));
    //                 else
    //                     systolic_array->set_input_index(i, j, sc_uint<4>(0));
    //             }
    //         }
    //     }
    // }



    void preload_inputs_into_buffer_(int buffer, int tile_id) {
        const int col_start = tile_id * ColsB;
        const int col_end   = col_start + ColsB;
        const int gcol_end_clamped = (col_end < colsA) ? col_end : colsA;

        for (int local_c = 0, gcol = col_start; gcol < gcol_end_clamped; ++gcol, ++local_c) {
            for (int r = 0; r < rowsA; ++r) {
                sc_int<8> v = preload_matA[r][gcol];
                input_buffer[buffer][local_c][r] = v;

                addr_row_input.write(local_c);
                addr_col_input.write(r);
                din_input.write((sc_int<32>)v);
                we_input.write(true);
                re_input.write(false);
                wait();
                we_input.write(false);

                din_input.write(0);
                addr_row_input.write(0);
                addr_col_input.write(0);
            }
            for (int r = rowsA; r < MAX_ROWS_A; ++r) {
                input_buffer[buffer][local_c][r] = 0; 
            }
        }
        for (int gcol = gcol_end_clamped; gcol < col_end; ++gcol) {
            int local_c = gcol - col_start;
            for (int r = 0; r < MAX_ROWS_A; ++r) {
                input_buffer[buffer][local_c][r] = 0;
            }
        }
    }

    void preload_inputs_thread() {
        we_input.write(false);
        re_input.write(false);
        din_input.write(0);
        addr_row_input.write(0);
        addr_col_input.write(0);
        wait();
        while (true) {
            if (start_input_preload_sig.read()) {
                preload_inputs_into_buffer_(preload_buffer, preload_input_tile_index);
                input_preload_done_sig.write(true); 
            } else {
                input_preload_done_sig.write(false);
                we_input.write(false);
                re_input.write(false);
                din_input.write(0);
                addr_row_input.write(0);
                addr_col_input.write(0);
            }
            wait();
        }
    }

    void preload_weights_thread() {
        we_weight.write(false);
        re_weight.write(false);
        we_input_index.write(false);
        re_input_index.write(false);
        din_weight.write(0);
        din_input_index.write(0);
        addr_row_weight.write(0);
        addr_col_weight.write(0);
        addr_row_input_index.write(0);
        addr_col_input_index.write(0);
        wait();
        while (true) {
            if (start_weight_preload_sig.read()) {
                preload_weights_cfg_();
                weight_preload_done_sig.write(true);  
            } else {
                weight_preload_done_sig.write(false);
                we_weight.write(false);
                re_weight.write(false);
                din_weight.write(0);
                addr_row_weight.write(0);
                addr_col_weight.write(0);

                we_input_index.write(false);
                re_input_index.write(false);
                din_input_index.write(0);
                addr_row_input_index.write(0);
                addr_col_input_index.write(0);
            }
            wait();
        }
    }

    void update_X_in_sig_cthread() {
        for (int col = 0; col < ColsB; ++col)
            for (int k = 0; k < MUX_INPUTS; ++k)
                X_in_sig[col][k].write(0);
        wait();
        while (true) {
            if (reset.read()) {
                for (int col = 0; col < ColsB; ++col)
                    for (int k = 0; k < MUX_INPUTS; ++k)
                        X_in_sig[col][k].write(0);
                wait();
                continue;
            }
            for (int col = 0; col < ColsB; ++col)
                for (int k = 0; k < MUX_INPUTS; ++k)
                    X_in_sig[col][k].write( input_pipeline_data_out[col][k].read() );
            wait();
        }
    }

    void stream_inputs_cthread() {
        for (int col = 0; col < ColsB; ++col)
            for (int l = 0; l < MUX_INPUTS; ++l)
                input_pipeline_data_in[col][l].write(0);
        wait();

        while (true) {
            if (!stream_enable.read()) {
                for (int col = 0; col < ColsB; ++col)
                    for (int l = 0; l < MUX_INPUTS; ++l)
                        input_pipeline_data_in[col][l].write(0);
                wait();
                continue;
            }

            if (cur_m < rowsA) {
                if (!inject_phase) {
                    
                    for (int col = 0; col < (int)colsB_eff.read(); ++col) {
                        int sz = (int)group_size[col];
                        if (sz > MUX_INPUTS) sz = MUX_INPUTS;

                        sc_int<8> v0 = 0;
                        if (sz >= 1) {
                            int k0 = (int)groups_map[col][0];
                            if (k0 >= 0 && k0 < colsA) v0 = preload_matA[cur_m][k0];
                        }
                        input_pipeline_data_in[col][0].write(v0);

                        sc_int<8> v1 = 0;
                        if (sz >= 2) {
                            int k1 = (int)groups_map[col][1];
                            if (k1 >= 0 && k1 < colsA) v1 = preload_matA[cur_m][k1];
                        }
                        input_pipeline_data_in[col][1].write(v1);

                        for (int l = 2; l < MUX_INPUTS; ++l)
                            input_pipeline_data_in[col][l].write(0);
                    }

                    slot_t = S_MAX;         
                    inject_phase = true;
                }
                else if (flush_counter < flush_len()) {
                    for (int col = 0; col < ColsB; ++col)
                        for (int l = 0; l < MUX_INPUTS; ++l)
                            input_pipeline_data_in[col][l].write(0);
                    flush_counter++;
                }
                else {
                    stream_row_done = true;
                    if (cur_m + 1 == rowsA) all_rows_done = true;
                    cur_m++;
                    flush_counter = 0;
                    inject_phase  = false;
                    slot_t        = 0;     
                }
            } else {
                for (int col = 0; col < ColsB; ++col)
                    for (int l = 0; l < MUX_INPUTS; ++l)
                        input_pipeline_data_in[col][l].write(0);
            }
            wait();
        }
    }



    void capture_and_write_outputs_cthread() {
        we_output.write(false);
        cap_row = 0;
        wait();
        while (true) {
            wait();
            // Capture exactly when the pipeline has fully flushed this tile
            // if (current_state == FLUSH && flush_counter == flush_len()) {
            //     for (int row = 0; row < RowsB; ++row) {
            //         output_line[row] = get_partial_sum(row, RIGHT_COL);
            //         din_output[row].write(output_line[row]);
            //     }
            //     we_output.write(true);
            //     addr_row_output.write(0);
            //     addr_col_output.write(current_tile);
            //     wait();
            //     we_output.write(false);
            // }
        }
    }


    void controller_fsm_cthread() {
        do_reset();
        wait();

        while (true) {
            switch (current_state) {
                case IDLE: {
                    rowsA = (int)rowsA_cfg.read();
                    colsA = (int)colsA_cfg.read();
                    rowsA = (rowsA > MAX_ROWS_A) ? MAX_ROWS_A : rowsA;
                    colsA = (colsA > MAX_COLS_A) ? MAX_COLS_A : colsA;

                    rowsB_eff.write(rowsB_eff_cfg.read());
                    colsB_eff.write(colsB_eff_cfg.read());

                    if (!preload_done_once) {
                        start_weight_preload_sig.write(true);
                        start_input_preload_sig.write(true);
                        wait();
                        start_weight_preload_sig.write(false);
                        start_input_preload_sig.write(false);

                        bool w_done=false, i_done=false;
                        while (!(w_done && i_done)) {
                            if (weight_preload_done_sig.read()) w_done = true;
                            if (input_preload_done_sig.read())  i_done = true;
                            wait();
                        }
                        preload_done_once = true;
                    }

                    rebuild_lane_map_from_groups();

                    int Gdbg = colsB_eff.read().to_uint();
                    std::cout << "[DBG] colsB_eff=" << Gdbg << "\n";
                    for (int g = 0; g < Gdbg; ++g) {
                        std::cout << "[DBG] group " << g << " size=" << (int)group_size[g] << " lanes:";
                        for (int l = 0; l < (int)group_size[g]; ++l)
                            std::cout << " " << (int)lane_map_col[g][l];
                        std::cout << "\n";
                    }

                    total_input_tiles = ceil_div_int(colsA, ColsB);
                    if (total_input_tiles < 1) total_input_tiles = 1;

                    preload_input_tile_index = 0;
                    start_input_preload_sig.write(true);
                    wait();
                    start_input_preload_sig.write(false);
                    swap(active_buffer, preload_buffer);
                    cur_m = 0;
                    cur_k = 0;


                    current_column = 0;
                    flush_counter  = 0;
                    compute_cycle  = 0;
                    stream_enable.write(true);
                    done_tile.write(false);
                    current_tile = 0;
                    preload_buffer_ready = false;

                    current_state = COMPUTE;
                    break;
                }

                case PRELOAD_CFG:
                    current_state = WAIT_CFG; 
                    break;

                case WAIT_CFG:
                    current_state = COMPUTE;
                    break;

                case COMPUTE: {
                    compute_cycle++;

                    if (compute_cycle == 1 && preload_input_tile_index < total_input_tiles) {
                        start_input_preload_sig.write(true);
                        wait();
                        start_input_preload_sig.write(false);
                    }
                    if (!preload_buffer_ready && input_preload_done_sig.read()) {
                        preload_buffer_ready = true;
                        preload_input_tile_index++;
                    }

                    if (slot_t >= S_MAX) {
                        current_state = FLUSH;
                    }
                    if (all_rows_done && slot_t >= S_MAX && flush_counter >= flush_len()) {
                        stream_enable.write(false);
                        done_tile.write(true);
                        current_state = DONE;
                    }
                    break;
                }

                case FLUSH: {
                    static constexpr int PIPE_LAT = 0;
                    const int FLUSH_LEN = static_cast<int>(colsB_eff.read().to_uint()) - 1 + PIPE_LAT;
                    if (flush_counter >= flush_len()){
                        current_tile++;
                        if (current_tile < total_input_tiles) {
                            if (preload_buffer_ready) {
                                std::swap(active_buffer, preload_buffer);
                                preload_buffer_ready = false;
                                cur_m = 0;            
                                cur_k = 0;              
                                current_column = 0;
                                flush_counter  = 0;
                                compute_cycle  = 0;
                                stream_enable.write(true);
                                current_state = COMPUTE;
                            } else {
                                wait();
                            }
                        } else {
                            stream_enable.write(false);
                            done_tile.write(true);
                            fsm_tile_complete = true;
                            current_state = DONE;
                        }
                    }
                    break;
                }

                case NEXT_TILE:
                    current_state = COMPUTE;
                    break;

                case DONE:
                    done_tile.write(true);
                    stream_enable.write(false);
                    if(go.read()) {
                        done_tile.write(false);
                        preload_done_once = false;
                        current_state = IDLE;
                    }
                    break;
            }
            wait();
        }
    }

    SC_CTOR(Controller, sc_signal<sc_int<8>> (&X_in_ref)[ColsB][MUX_INPUTS])
    : X_in_sig(X_in_ref)
    {
        for (int i = 0; i < ColsB; i++) {
            std::string name = "flipflop_" + std::to_string(i);
            input_pipeline[i] = new InputRegisterArray(name.c_str(), i);
            input_pipeline[i]->clk(clk);
            input_pipeline[i]->reset(reset);
            for (int k = 0; k < MUX_INPUTS; k++) {
                input_pipeline[i]->data_in[k](input_pipeline_data_in[i][k]);
                input_pipeline[i]->data_out[k](input_pipeline_data_out[i][k]);
            }
        }

        SC_CTHREAD(controller_fsm_cthread, clk.pos());
        async_reset_signal_is(reset, true);

        SC_CTHREAD(stream_inputs_cthread, clk.pos());
        async_reset_signal_is(reset, true);

        SC_CTHREAD(update_X_in_sig_cthread, clk.pos());
        async_reset_signal_is(reset, true);

        SC_CTHREAD(capture_and_write_outputs_cthread, clk.pos());
        async_reset_signal_is(reset, true);

        SC_CTHREAD(preload_weights_thread, clk.pos());
        async_reset_signal_is(reset, true);

        SC_CTHREAD(preload_inputs_thread, clk.pos());
        async_reset_signal_is(reset, true);
    }

    ~Controller() {
        for (int i = 0; i < ColsB; i++) delete input_pipeline[i];
    }
};

#endif





















































