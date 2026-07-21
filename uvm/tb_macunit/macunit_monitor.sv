// Monitor does not recieve items from sequencer instead it only watches DUT pins through the interface


class macunit_monitor extends uvm_monitor;

    `uvm_component_utils(macunit_monitor)

    virtual macunit_intf vif;

    uvm_analysis_port #(macunit_seq_item) monitor_ap;   // input port of monitor
    // monitor sends observed macunit_seq_item objects through this port and then in environment, this gets connected to scoreboard

    bit [7:0] stored_weight;

    function new(string name = "macunit_monitor", uvm_component parent);
        super.new(name, parent);
        monitor_ap = new("monitor_ap", this);    // this creates the analysis port
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual macunit_intf)::get(this, "", "vif", vif)) begin
            `uvm_fatal("Monitor", "Could not get virtual interface")
        end
    endfunction

    task run_phase(uvm_phase phase);
        macunit_seq_item tr;

        stored_weight = '0;

        forever begin
            @(posedge vif.clk);
            #1;

            if (vif.rst) begin
                stored_weight = '0;
            end

            if (vif.load_w) begin
                stored_weight = vif.w_in;

                `uvm_info("MON", $sformatf(
                    "Weight loaded: w_input=%0d",
                    stored_weight
                ), UVM_MEDIUM)
            end

            if (vif.en && vif.start) begin

                tr = macunit_seq_item::type_id::create("tr");

                tr.w_input = stored_weight;
                tr.x_input = '0;
                tr.y_output   = '0;

                for (int i = 0; i < 32; i++) begin

                    if (i != 0) begin
                        @(posedge vif.clk);
                        #1;
                    end

                    if (i < 8) begin
                        tr.x_input[i] = vif.x_in;   
                    end

                    tr.y_output[i] = vif.y_out;       
                end

                tr.calculate_expected();

                `uvm_info("MON", $sformatf(
                    "Observed MAC operation: x_input=%0d, w_input=%0d, y_out=%0d, expected=%0d",
                    tr.x_input,tr.w_input,tr.y_output,tr.expected_y_out), UVM_MEDIUM)

                monitor_ap.write(tr);
            end
        end
    endtask

endclass