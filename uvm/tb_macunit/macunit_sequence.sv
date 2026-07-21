class macunit_sequence extends uvm_sequence;

    `uvm_object_utils(macunit_sequence)         // registering sequence with the UVM factory

    function new(string name="macunit_sequence");
        super.new(name);
    endfunction

    task body();
        macunit_seq_item req;  // object

        req = macunit_seq_item::type_id::create("req");

        start_item(req); // to inform sequencer that prepare/send one transaction
        req.w_input = 8'b0000_1011;
        req.x_input = 8'b0000_1000;
        req.calculate_expected();
        finish_item(req);

        repeat(1000) begin
            req = macunit_seq_item::type_id::create("req");
            start_item(req);

            // if (!req.randomize()) begin
            //     `uvm_fatal("SEQ", "Randomization failed")
            // end

            req.x_input = $urandom_range(0, 255);
            req.w_input = $urandom_range(0, 255);

            req.calculate_expected();

            finish_item(req);
        end
    endtask
endclass