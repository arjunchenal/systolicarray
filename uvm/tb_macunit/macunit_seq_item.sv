class macunit_seq_item extends uvm_sequence_item;

    rand bit [7:0] x_input; // input
    rand bit [7:0] w_input;   // weight

    bit[31:0] y_output;
    bit[31:0] expected_y_out;


    `uvm_object_utils_begin(macunit_seq_item)      // register the class to UVM factory -> helps UVM to create,print,copy,compare,record,debug
        `uvm_field_int(w_input, UVM_ALL_ON)
        `uvm_field_int(x_input, UVM_ALL_ON)
        `uvm_field_int(y_output, UVM_ALL_ON)
        `uvm_field_int(expected_y_out, UVM_ALL_ON)
    `uvm_object_utils_end

    // constructor
    function new(string name="macunit_seq_item");
        super.new(name);    // parent class constructor
    endfunction


    function void calculate_expected();
        // expected_y_out = x_input * w_input;
        logic [31:0]        x_ext;
        logic signed [31:0] w_ext;
        logic signed [31:0] result;

        x_ext  = {24'd0, x_input};
        w_ext  = {{24{w_input[7]}}, w_input};
        result = x_ext * w_ext;

        expected_y_out = result;
    endfunction


endclass