# Compiler
CC = g++

# SystemC paths (adjust to your installation)
SYSTEMC_INCLUDE = C:/SystemC/include
SYSTEMC_LIB = C:/SystemC/lib

# Flags
CFLAGS = -std=c++17 -g -I$(SYSTEMC_INCLUDE) -Iinclude -Isrc -Itb
LDFLAGS = -L$(SYSTEMC_LIB) -lsystemc -lm

# Directories
SRC_DIR = src
INCLUDE_DIR = include
TB_DIR = testbench
BUILD_DIR = build

# Executable outputs
WEIGHTED_EXEC = $(BUILD_DIR)/tb_weightedstationary.exe

# Common source files
COMMON_SOURCES = $(SRC_DIR)/alu.cpp $(SRC_DIR)/accumulator.cpp $(SRC_DIR)/sram.cpp $(SRC_DIR)/systolic_array.cpp $(SRC_DIR)/macunit.cpp $(SRC_DIR)/controller.cpp $(SRC_DIR)/input_register_array.cpp


# Specific sources per testbench
WEIGHTED_SOURCES = $(TB_DIR)/testbench_systolic_array.cpp $(SRC_DIR)/sram.cpp $(COMMON_SOURCES)

# Default target: build everything
all: $(WEIGHTED_EXEC)

# Weighted-stationary executable
$(WEIGHTED_EXEC): $(WEIGHTED_SOURCES) | $(BUILD_DIR)
	@echo "Building weighted-stationary testbench..."
	$(CC) $(CFLAGS) $(WEIGHTED_SOURCES) -o $(WEIGHTED_EXEC) $(LDFLAGS)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	-mkdir $(BUILD_DIR)

# Run weighted-stationary simulation and save to log
run_weighted: $(WEIGHTED_EXEC)
	@echo "Running weighted-stationary simulation..."
	@./$(WEIGHTED_EXEC) > logs/weighted_stationary.log 2>&1
	@echo "Simulation output saved to logs/weighted_stationary.log"



# run_weighted: $(WEIGHTED_EXEC)
# 	@echo "Running weighted-stationary simulation..."
# 	@./$(WEIGHTED_EXEC)


# Clean everything
clean:
	@echo "Cleaning up..."
	-rm -rf $(BUILD_DIR) *.vcd

# Phony targets
.PHONY: all clean run_output run_weighted




















# # Compiler
# CC = g++

# # SystemC paths (adjust to your installation)
# SYSTEMC_INCLUDE = C:/SystemC/include
# SYSTEMC_LIB = C:/SystemC/lib

# # Flags
# CFLAGS = -std=c++17 -g -O0 -I$(SYSTEMC_INCLUDE) -Iinclude -Isrc -Itb
# LDFLAGS = -L$(SYSTEMC_LIB) -lsystemc -lm
# # Add AddressSanitizer for memory error detection
# ASAN_FLAGS = -fsanitize=address -fno-omit-frame-pointer

# # Directories
# SRC_DIR = src
# INCLUDE_DIR = include
# TB_DIR = testbench
# BUILD_DIR = build
# LOG_DIR = logs

# # Executable outputs
# WEIGHTED_EXEC = $(BUILD_DIR)/tb_weightedstationary.exe
# WEIGHTED_EXEC_ASAN = $(BUILD_DIR)/tb_weightedstationary_asan.exe

# # Common source files
# COMMON_SOURCES = $(SRC_DIR)/alu.cpp $(SRC_DIR)/accumulator.cpp $(SRC_DIR)/sram.cpp $(SRC_DIR)/systolic_array.cpp $(SRC_DIR)/macunit.cpp $(SRC_DIR)/controller.cpp $(SRC_DIR)/input_register_array.cpp

# # Specific sources per testbench
# WEIGHTED_SOURCES = $(TB_DIR)/testbench_systolic_array.cpp $(SRC_DIR)/sram.cpp $(COMMON_SOURCES)

# # Default target: build everything
# all: $(WEIGHTED_EXEC)

# # Weighted-stationary executable (standard)
# $(WEIGHTED_EXEC): $(WEIGHTED_SOURCES) | $(BUILD_DIR)
# 	@echo "Building weighted-stationary testbench..."
# 	$(CC) $(CFLAGS) $(WEIGHTED_SOURCES) -o $(WEIGHTED_EXEC) $(LDFLAGS)

# # Weighted-stationary executable with AddressSanitizer
# $(WEIGHTED_EXEC_ASAN): $(WEIGHTED_SOURCES) | $(BUILD_DIR)
# 	@echo "Building weighted-stationary testbench with AddressSanitizer..."
# 	$(CC) $(CFLAGS) $(ASAN_FLAGS) $(WEIGHTED_SOURCES) -o $(WEIGHTED_EXEC_ASAN) $(LDFLAGS)

# # Create build directory if it doesn't exist
# $(BUILD_DIR):
# 	-mkdir $(BUILD_DIR)

# # Create logs directory if it doesn't exist
# $(LOG_DIR):
# 	-mkdir $(LOG_DIR)

# # Run weighted-stationary simulation and save to log
# run_weighted: $(WEIGHTED_EXEC) | $(LOG_DIR)
# 	@echo "Running weighted-stationary simulation..."
# 	@./$(WEIGHTED_EXEC) > $(LOG_DIR)/weighted_stationary.log 2>&1
# 	@echo "Simulation output saved to $(LOG_DIR)/weighted_stationary.log"

# # Run weighted-stationary simulation with AddressSanitizer
# run_weighted_asan: $(WEIGHTED_EXEC_ASAN) | $(LOG_DIR)
# 	@echo "Running weighted-stationary simulation with AddressSanitizer..."
# 	@./$(WEIGHTED_EXEC_ASAN) > $(LOG_DIR)/weighted_stationary_asan.log 2>&1
# 	@echo "Simulation output saved to $(LOG_DIR)/weighted_stationary_asan.log"

# # Run weighted-stationary simulation with gdb
# run_weighted_gdb: $(WEIGHTED_EXEC) | $(LOG_DIR)
# 	@echo "Running weighted-stationary simulation under gdb..."
# 	@gdb --batch --ex run --ex bt --ex quit ./$(WEIGHTED_EXEC) > $(LOG_DIR)/weighted_stationary_gdb.log 2>&1
# 	@echo "GDB output saved to $(LOG_DIR)/weighted_stationary_gdb.log"

# # Clean everything
# clean:
# 	@echo "Cleaning up..."
# 	-rm -rf $(BUILD_DIR) *.vcd $(LOG_DIR)

# # Phony targets
# .PHONY: all clean run_weighted run_weighted_asan run_weighted_gdb