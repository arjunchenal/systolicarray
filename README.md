# Compression-Aware Hybrid MAC Architecture for Energy-Area-Delay optimization in the Systolic Arrays

## Overview

This repository contains the RTL and architectural models of a **compression aware weight-stationary systolic-array accelerator** for General Matrix Multiplication (**GEMM**) and neural-network inference.

The project investigates how different multiply-accumulate (**MAC**) architectures affect the:

* Effective throughput
* Hardware area
* Critical-path delay
* Power consumption
* Energy per operation
* Overall area–energy–delay trade-off

Three functionally equivalent MAC architectures are implemented and evaluated:

1. **Bit-Serial MAC**
2. **Bit-Parallel MAC**
3. **Bit-Hybrid MAC**

---

## Project Motivation

A conventional bit-parallel MAC performs an entire multiplication in one cycle. Although this provides low cycle latency, the large combinational multiplier introduces considerable area and a long critical path.

A bit-serial MAC processes one activation bit per cycle. This significantly reduces the combinational hardware, but an 8-bit multiplication requires eight cycles.

The proposed bit-hybrid architecture provides a middle ground between these two designs. It processes four activation bits per cycle and therefore completes an 8-bit multiplication in two cycles.

The main objective of this project is to determine whether the hybrid architecture can provide:

* Higher effective throughput than the bit-serial architecture
* A shorter critical path than the bit-parallel architecture
* Lower energy consumption than both baseline architectures
* A better overall area–energy–delay trade-off

---

## Implemented Architectures

### 1. Bit-Serial MAC

The bit-serial MAC processes one activation bit during each clock cycle.

For an 8-bit activation:

```text
Bits processed per cycle : 1
Cycles per multiplication: 8
```

The architecture uses a chain of full adders instead of a conventional parallel multiplier. Partial products are accumulated according to the position of the currently processed input bit.

#### Advantages

* Small combinational datapath
* High maximum clock frequency
* Reduced hardware complexity

#### Limitations

* Eight cycles are required for one 8-bit multiplication
* Lower effective throughput
* Additional control and state registers are required

---

### 2. Bit-Parallel MAC

The bit-parallel MAC receives the complete 8-bit activation and 8-bit weight simultaneously.

```text
Bits processed per cycle : 8
Cycles per multiplication: 1
```

It uses a conventional parallel multiplier followed by an accumulator.

#### Advantages

* One-cycle multiplication
* Simple control flow
* Straightforward RTL implementation

#### Limitations

* Large combinational multiplier
* Longer critical path
* Lower achievable clock frequency
* Higher hardware and energy cost

---

### 3. Proposed Bit-Hybrid MAC

The proposed hybrid MAC processes four activation bits per cycle.

```text
Bits processed per cycle : 4
Cycles per multiplication: 2
Input radix              : 16
```

Four input bits are processed in parallel using four bit-level multiplication paths. The generated partial products are shifted according to their bit positions and combined before being added to the running accumulator.

For input bits `x[3:0]` and an 8-bit weight `W`, the partial result for one cycle is:

```text
Partial Result =
    (x[0] × W)       +
    (x[1] × W << 1)  +
    (x[2] × W << 2)  +
    (x[3] × W << 3)
```

During the second cycle, the upper four activation bits are processed and shifted by an additional four bit positions.

The hybrid architecture therefore combines the higher clock-frequency potential of the bit-serial architecture with the reduced cycle count of the bit-parallel architecture.

#### Advantages

* Four activation bits processed per cycle
* Only two cycles required for an 8-bit multiplication
* Shorter critical path than the bit-parallel implementation
* Higher effective throughput than both baseline architectures
* Best overall energy–area–delay trade-off in the evaluated implementation

---

## Weight-Stationary Systolic Array

All three MAC architectures are integrated into a parameterizable **32 × 32 weight-stationary systolic array**.

In the weight-stationary dataflow:

1. Weights and Input Index LUT are loaded into the processing elements.
2. Input activations propagate horizontally through the array.
3. With the help of Input Index LUT value stored inside each PE local register, corresponding input lane is picked by the PE out of all the available input lanes.
4. Partial sums propagate vertically between processing elements.
5. Each processing element reuses its stored weight over multiple computations.
6. Completed output values are collected in the output buffer.

The same matrix-multiplication workload is executed using the serial, parallel, and hybrid implementations to ensure a fair architectural comparison.

---

## Compression-Aware Execution

The repository also explores sparse matrix acceleration using a **column-combining compression scheme**.

An Integer Linear Programming (**ILP**) formulation is used to group compatible sparse weight columns while avoiding conflicts between nonzero weight positions.

The compression flow is intended to:

* Reduce the number of physical columns required by the systolic array
* Improve processing-element utilization
* Reduce redundant zero-valued operations
* Improve effective throughput for sparse neural-network layers
* Evaluate the interaction between sparsity and MAC architecture

The compression implementation is currently under active development.

---

## Implementation and Evaluation Flow

The architectures are evaluated using the following flow:

```text
SystemC Architectural Model
            ↓
VHDL RTL Implementation
            ↓
Functional Simulation
            ↓
Logic Synthesis
            ↓
Placement and Routing
            ↓
Post-Layout Timing Analysis
            ↓
SAIF-Based Power Analysis
            ↓
Area, Energy and Performance Comparison
```

### Tools

* **SystemC** for architectural modelling
* **VHDL** for RTL implementation
* **ModelSim/QuestaSim** for functional simulation
* **Synopsys Design Compiler** for logic synthesis
* **Cadence Innovus** for placement and routing
* **SAIF-based activity annotation** for post-layout power estimation
* **Python** for test-vector generation and result analysis
* **Gurobi** for solving the compression ILP
* **Tcl** for synthesis and physical-design automation

The designs are evaluated using a **45 nm FreePDK technology flow**.

---

## Results Summary

Post-layout analysis shows that the bit-hybrid architecture provides the best overall architectural trade-off.

| Architecture | Bits per Cycle | Cycles per 8-bit MAC | Approximate Clock Frequency | Main Characteristic                             |
| ------------ | -------------: | -------------------: | --------------------------: | ----------------------------------------------- |
| Bit-Serial   |              1 |                    8 |                    1.53 GHz | Small datapath but high cycle count             |
| Bit-Hybrid   |              4 |                    2 |                    0.83 GHz | Best effective throughput and overall trade-off |
| Bit-Parallel |              8 |                    1 |                    0.25 GHz | One-cycle operation but long critical path      |

Although the bit-parallel architecture completes a multiplication in one cycle, its long combinational path limits the maximum clock frequency.

The bit-serial architecture achieves the highest clock frequency, but its eight-cycle multiplication latency reduces effective throughput.

The bit-hybrid architecture achieves the highest effective multiplication rate because it requires only two cycles while maintaining a substantially higher clock frequency than the bit-parallel design.

### Main Findings

* The hybrid architecture achieves the **best effective throughput** among the three evaluated designs.
* It consumes approximately **57% less energy than the bit-serial architecture**.
* It consumes approximately **33% less energy than the bit-parallel architecture**.
* It provides the best evaluated **energy–area–delay product**.
* It offers a balanced architecture between the hardware-heavy parallel MAC and the latency-heavy serial MAC.

Therefore, the hybrid architecture does not necessarily have the smallest area, lowest instantaneous power, or shortest cycle count individually. Instead, it provides the best combined balance of performance, area, and energy efficiency.

---

## Repository Structure

```text
Tight_compression_systolic/
│
├── data/
│   ├── input_weight_generator.py
│   ├── inputs.txt
│   ├── weights.txt
│   └── output.txt
│
├── include/
│   └── SystemC header files
│
├── logs/
│   └── SystemC simulation logs
│
├── src/
│   └── SystemC source files
│
├── testbench/
│   └── SystemC testbench files
│
├── vhdl/
│   │
│   ├── systolic_array_mac_parallel/
│   │   ├── accelerator.vhd
│   │   ├── controller.vhd
│   │   ├── input_register_array.vhd
│   │   ├── macunit_parallel.vhd
│   │   ├── output_buffer.vhd
│   │   ├── sram.vhd
│   │   ├── systolic_array.vhd
│   │   └── tb_Systolic_Array.vhd
│   │
│   ├── systolic_array_mac_serial/
│   │   ├── accelerator.vhd
│   │   ├── controller.vhd
│   │   ├── input_register_array.vhd
│   │   ├── macunit_serial.vhd
│   │   ├── outputcollector.vhd
│   │   ├── sram.vhd
│   │   ├── systolic_array.vhd
│   │   └── tb_Systolic_Array.vhd
│   │
│   └── systolic_array_mac_hybrid/
│       ├── accelerator.vhd
│       ├── controller.vhd
│       ├── input_register_array.vhd
│       ├── macunit_hybrid.vhd
│       ├── outputcollector.vhd
│       ├── sram.vhd
│       ├── systolic_array.vhd
│       └── tb_Systolic_Array.vhd
│
├── Makefile
└── README.md
```

---

## VHDL Simulation

### Prerequisites

* ModelSim or QuestaSim
* Python 3
* VHDL-2008-compatible simulator

### 1. Generate Test Data

Run the Python test-vector generator:

```bash
python3 data/input_weight_generator.py
```

The script generates:

```text
inputs.txt
weights.txt
output.txt
```

The `output.txt` file contains the expected matrix-multiplication result.

---

### 2. Create a ModelSim Project

Create a new ModelSim or QuestaSim project and add all VHDL files from the architecture that you want to simulate.

For example:

```text
vhdl/systolic_array_mac_parallel/
```

or:

```text
vhdl/systolic_array_mac_serial/
```

or:

```text
vhdl/systolic_array_mac_hybrid/
```

Compile the source files in dependency order.

---

### 3. Copy the Input Files

Copy the generated files into the ModelSim simulation working directory:

```text
inputs.txt
weights.txt
output.txt
```

Make sure the file names and paths match those used by the VHDL testbench.

---

### 4. Run the Simulation

Start the corresponding testbench and execute:

```tcl
run -all
```

The testbench:

1. Loads the input and weight matrices.
2. Executes the matrix multiplication.
3. Collects the systolic-array outputs.
4. Compares the RTL result against the expected output.
5. Reports mismatches in the simulator console.

The waveform can also be inspected to verify:

* Weight loading
* Input wavefront propagation
* Processing-element activity
* Partial-sum propagation
* Output-valid timing
* Output collection

---

## SystemC Simulation

### Prerequisites

* C++ compiler with C++17 support
* SystemC 3.x
* GNU Make

The SystemC installation path may need to be configured in the `Makefile`.

---

### Clean the Build Directory

```bash
make clean
```

This command removes generated files such as:

* Object files
* Simulation executables
* Temporary build files
* VCD waveform files

Use it before rebuilding the project to avoid stale compilation artifacts.

---

### Compile and Run the Weight-Stationary Model

```bash
make run_weighted
```

This command:

1. Compiles the SystemC source files.
2. Builds the simulation executable.
3. Executes the weight-stationary systolic-array model.
4. Writes simulation logs.
5. Generates a VCD waveform file.

The generated waveform can be opened using tools such as GTKWave.

---

## Functional Equivalence

All three implementations are designed to produce the same numerical matrix-multiplication result.

The architectures differ only in how multiplication is performed internally:

```text
Bit-Serial   : 1 input bit per cycle
Bit-Hybrid   : 4 input bits per cycle
Bit-Parallel : 8 input bits per cycle
```

Functional equivalence is verified by comparing the output of each RTL implementation against the same Python-generated reference result.

---

## Conclusion

This project demonstrates that reducing the cycle count alone does not guarantee the best accelerator performance.

The bit-parallel architecture has a one-cycle multiplication latency but suffers from a long critical path. The bit-serial architecture achieves a high clock frequency but requires eight cycles per multiplication.

The proposed four-bit-per-cycle hybrid architecture balances these two extremes. In the evaluated 32 × 32 weight-stationary systolic array, it achieves the highest effective throughput and the best overall area–energy–delay trade-off.

The results show that the bit-hybrid architecture is a promising solution for energy-efficient neural-network accelerators, particularly when combined with compression-aware execution for sparse workloads.
