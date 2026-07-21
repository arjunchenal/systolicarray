# Pin assignment tcl #

# clk rst en and load_w
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Top -layer 6 -spreadType start -spacing 1.0 -start 0.0 0.0 -pin {clk en rst load_w}

# input bits in systolic from left side
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left -layer 5 -spreadType start -spacing 1.0 -start 0.0 0.0 -pin {x_col_bits* row_id_data_in*}

set w_right_3 {}
set w_right_5 {}
set w_left_3 {}
set w_left_5 {}

# 0–2047 right side
for {set i 0} {$i < 2048} {incr i} {
    lappend w_right_3 "w_mat\[$i\]"
}

# 2048–4095 left side
for {set i 2048} {$i < 4096} {incr i} {
    lappend w_right_5 "w_mat\[$i\]"
}

# 4096–6143 top side
for {set i 4096} {$i < 6144} {incr i} {
    lappend w_left_3 "w_mat\[$i\]"
}

# 6144–8191 bottom side
for {set i 6144} {$i < 8192} {incr i} {
    lappend w_left_5 "w_mat\[$i\]"
}


# weight matrix right side m3 metal
editPin -fixOverlap 1 -unit MICRON -side Right -layer 3 -spreadType SIDE -spacing 0.4 -pin $w_right_3

# weight matrix right side m5 metal
editPin -fixOverlap 1 -unit MICRON -side Right -layer 5 -spreadType SIDE -spacing 0.4 -pin $w_right_5

# weight matrix left side m3 metal
editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spreadType SIDE -spacing 0.4 -pin $w_left_3

# weight matrix left side m5 metal
editPin -fixOverlap 1 -unit MICRON -side Left -layer 5 -spreadType SIDE -spacing 0.4 -pin $w_left_5


# lut_mat Pin
set l_top_4 {}
set l_bottom_6 {}
set l_bottom_4 {}
set l_left_3 {}

# 0–2047 top side
for {set i 0} {$i < 2048} {incr i} {
    lappend l_top_4 "lut_mat\[$i\]"
}

# 2048–4095 bottom side
for {set i 2048} {$i < 4096} {incr i} {
    lappend l_bottom_6 "lut_mat\[$i\]"
}

# 4096–6143 bottom side
for {set i 4096} {$i < 6144} {incr i} {
    lappend l_bottom_4 "lut_mat\[$i\]"
}

# 6144–8191 left side
for {set i 6144} {$i < 8192} {incr i} {
    lappend l_left_3 "lut_mat\[$i\]"
}


# lut matrix top side m4 metal
editPin -fixOverlap 1 -unit MICRON -side Top -layer 4 -spreadType SIDE -spacing 0.4 -pin $l_top_4

# lut matrix bottom side m6 metal
editPin -fixOverlap 1 -unit MICRON -side Bottom -layer 6 -spreadType SIDE -spacing 0.4 -pin $l_bottom_6

# lut matrix Bottom m4 metal
editPin -fixOverlap 1 -unit MICRON -side Bottom -layer 4 -spreadType SIDE -spacing 0.4 -pin $l_bottom_4

# lut matrix left side m3 metal
editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spreadType SIDE -spacing 0.4 -pin $l_left_3


# output bits in systolic from bottom side
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Bottom -layer 6 -spreadType start -spacing 1.0 -start 0.0 0.0 -pin {y_row_bits*}

editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Bottom -layer 4 -spreadType start -spacing 1.0 -start 0.0 0.0 -pin {lane_valid_bits* row_id_data_out*}
