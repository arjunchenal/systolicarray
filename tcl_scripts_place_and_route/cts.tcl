add_ndr -name default_2x_space -spacing {metal1 0.38 metal2:metal5 0.42 metal6:metal8 0.84}

create_route_type -name leaf_rule  -non_default_rule default_2x_space -top_preferred_layer metal6 -bottom_preferred_layer metal2
create_route_type -name trunk_rule -non_default_rule default_2x_space -top_preferred_layer metal8 -bottom_preferred_layer metal2 -shield_net VSS -shield_side both_side
create_route_type -name top_rule   -non_default_rule default_2x_space -top_preferred_layer metal8 -bottom_preferred_layer metal2 -shield_net VSS -shield_side both_side

set_ccopt_property route_type -net_type leaf  leaf_rule
set_ccopt_property route_type -net_type trunk trunk_rule
set_ccopt_property route_type -net_type top   top_rule

setDesignMode -process 45

set_ccopt_property target_max_trans 0.08
set_ccopt_property target_skew 0.5

set_ccopt_property buffer_cells {BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16 BUF_X32 CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}
set_ccopt_property inverter_cells {INV_X1 INV_X2 INV_X4 INV_X8 INV_X16 INV_X32}

create_ccopt_clock_tree_spec -file ./results/ctsspec.tcl
source ./results/ctsspec.tcl
clock_opt_design