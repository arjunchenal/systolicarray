//============================================================================
// Author:  
// Date: 01-07-2025
// Description: Implementation of the ALU module for the systolic array based accelerator.
//              The ALU performs signed 8-bit multiplication of inputs X and Y on the positive
//              clock edge and outputs a 16-bit signed result.
//              This module is the core part of the MAC unit and is used for executing multiply 
//              operations in each PE's(Processing element).
//============================================================================

#include "alu.h"

void ALU::multiply() {
    while(true) {
        wait();
        sc_int<16> product = X.read() * Y.read();
        result.write(product);
    }

}
