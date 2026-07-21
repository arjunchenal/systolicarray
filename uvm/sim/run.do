quit -sim

vlib work
vmap work work

file mkdir logs
file mkdir waves
transcript file logs/macunit_sim.log


vlog -sv ../rtl/macunit.sv
vlog -sv ../tb_macunit/macunit_intf.sv
vlog -sv +incdir+../tb_macunit ./macunit_pkg.sv
vlog -sv ../tb_macunit/macunit_tb.sv


vsim -voptargs=+acc work.top +UVM_TESTNAME=macunit_test

view wave
add wave -r sim:/top/*
run -all

vcd file waves/macunit_wave.vcd
vcd add -r sim:/top/*

run -all

vcd flush
vcd off
transcript file ""