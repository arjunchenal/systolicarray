class macunit_driver extends uvm_driver #(macunit_seq_item);

    `uvm_component_utils(macunit_driver)

    virtual macunit_intf vif;

    function new(string name = "macunit_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual macunit_intf)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Could not get virtual interface")
        end
    endfunction

    task run_phase(uvm_phase phase);
        macunit_seq_item req;

        vif.rst    <= 1'b1;
        vif.en     <= 1'b0;
        vif.load_w <= 1'b0;
        vif.start  <= 1'b0;
        vif.w_in   <= '0;
        vif.x_in   <= 1'b0;
        vif.y_in   <= 1'b0;

        repeat (3) @(negedge vif.clk);
        vif.rst <= 1'b0;

        forever begin
            seq_item_port.get_next_item(req); //get transaction from sequencer

            drive_one_mac_operation(req);   // drive to DUT

            seq_item_port.item_done();      // 
        end
    endtask

    task drive_one_mac_operation(macunit_seq_item req);

        `uvm_info("DRV", $sformatf(
            "Driving MAC operation: x_input=%0d, w_input=%0d, expected=%0d",
            req.x_input, req.w_input, req.expected_y_out
        ), UVM_MEDIUM)  // print each time


        @(negedge vif.clk);
        vif.en     <= 1'b0;
        vif.load_w <= 1'b1;
        vif.start  <= 1'b0;
        vif.w_in   <= req.w_input;
        vif.x_in   <= 1'b0;
        vif.y_in   <= 1'b0;   


        for (int i = 0; i < 32; i++) begin
            @(negedge vif.clk);

            vif.en     <= 1'b1;
            vif.load_w <= 1'b0;
            vif.start  <= (i == 0);

            if (i < 8)
                vif.x_in <= req.x_input[i];   
            else
                vif.x_in <= 1'b0;

            vif.y_in <= 1'b0;                 
        end

        @(negedge vif.clk);
        vif.en     <= 1'b0;
        vif.load_w <= 1'b0;
        vif.start  <= 1'b0;
        vif.w_in   <= '0;
        vif.x_in   <= 1'b0;
        vif.y_in   <= 1'b0;

    endtask

endclass