# rtl design
read_file -format vhdl {../rtl/macunit_serial.vhd}
read_file -format vhdl {../rtl/pe.vhd}
read_file -format vhdl {../rtl/systolic_array.vhd}

#top module
current_design SystolicArray_serial
link

#clock
create_clock [get_ports clk]  -period 0.5  -waveform {0 0.25} -name clk
set_clock_uncertainty 0.025  -setup [get_clocks clk]
set_clock_uncertainty 0.025  -hold [get_clocks clk]
set_clock_transition -fall 0.04 [get_clocks clk]
set_clock_transition -rise 0.04 [get_clocks clk]
  
set_dont_touch clk
set_dont_touch rst
  
set_clock_latency -max -source 0.1 [get_clocks clk]

set_input_delay -max -clock clk 0.05 [get_ports {en load_w x_col_bits w_mat lut_mat row_id_data_in}]

set_output_delay -max -clock clk 0.05 [all_outputs]

set_false_path -from [get_ports rst]

#compile
check_timing
compile

#Reports
report_timing > reports/systolic_array_serial_p_1.timing
report_constraint -all_violators > reports/systolic_array_serial_p_1.violations
report_area > reports/systolic_array_serial_p_1.area
report_power > reports/systolic_array_serial_p_1_synth.power

change_names -hier -rules vhdl 
change_names -hier -rules verilog

#saving the output
write_file -hierarchy -f vhdl    -output "./results/systolic_array_serial_p_1.vhd"
write_file -hierarchy -f verilog -output "./results/systolic_array_serial_p_1.v"
write_sdf  "./results/systolic_array_serial_p_1.sdf"
write -hierarchy -f ddc -output  "./results/systolic_array_serial_p_1.ddc"
write_sdc "./results/systolic_array_serial_p_1.sdc"