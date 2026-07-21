class macunit_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(macunit_scoreboard)

    uvm_analysis_imp #(macunit_seq_item, macunit_scoreboard) scoreboard_imp;   // input port of scoreboard

    function new(string name = "macunit_scoreboard", uvm_component parent);
        super.new(name, parent);
        scoreboard_imp = new("scoreboard_imp", this);
    endfunction

    function void write(macunit_seq_item tr);
        if(tr.y_output !== tr.expected_y_out) begin
            `uvm_error("Scoreboard", $sformatf(
                "MAC mismatch: x_input=%0d, w_input=%0d, expected_y_out=%0d, actual_y_out=%0d",
                tr.x_input,
                tr.w_input,
                tr.expected_y_out,
                tr.y_output
            ))
        end
        else begin
            `uvm_info("Scoreboard", $sformatf(
                "mac correct: x_input=%0d, w_input=%0d, expected_y_out=%0d, actual_y_out=%0d",
                tr.x_input,
                tr.w_input,
                tr.expected_y_out,
                tr.y_output
            ), UVM_MEDIUM)
        end
    endfunction
endclass