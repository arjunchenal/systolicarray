class macunit_agent extends uvm_agent;

    `uvm_component_utils(macunit_agent)

    macunit_sequencer sequencer;
    macunit_driver driver;
    macunit_monitor monitor;

    function new(string name="macunit_agent", uvm_component parent);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // hierarchy is agent.sequencer, agent.driver, agent.monitor
        sequencer = macunit_sequencer::type_id::create("sequencer", this);  // 'this' means its inside the agent
        driver = macunit_driver::type_id::create("driver", this);
        monitor = macunit_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass
