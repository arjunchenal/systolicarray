    
#include "macunit.h"    
    
    
void MacUnit::set_weight(sc_int<8> w) {
    weight = w;
}

void MacUnit::set_input_index(sc_uint<4> id_index) {
    input_index = id_index;
}

void MacUnit::process() {
    clear_sig.write(true);
    for(int k = 0; k < MUX_INPUTS; k++) {
        X_out[k].write(0);
    }
    X_sig.write(0);
    Y_sig.write(0);
    result.write(0);
    wait();

    while(true) {
        clear_sig.write(false);

        sc_uint<4> sel = mux_sel.read();
        sc_int<8> xin = X_in[sel].read();
        
        X_sig.write(xin);
        Y_sig.write(weight);

        for(int k = 0; k < MUX_INPUTS; k++) {
            X_out[k].write(X_in[k].read());
        }

        result.write( (sc_int<32>)alu_out_sig.read() + partial_sum_in.read() );

        wait();
    }
}
