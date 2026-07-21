class macunit_sequencer extends uvm_sequencer #(macunit_seq_item);
    `uvm_component_utils(macunit_sequencer)

    function new(string name="macunit_sequencer", uvm_component parent);
        super.new(name, parent); 
    endfunction

endclass