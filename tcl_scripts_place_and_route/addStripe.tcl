addStripe -nets {VDD VSS} -layer metal9 -direction vertical -width 2.5 -spacing 2 -set_to_set_distance 50 -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1

addStripe -nets {VDD VSS} -layer metal10 -direction horizontal -width 2.5 -spacing 2 -set_to_set_distance 50 -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1