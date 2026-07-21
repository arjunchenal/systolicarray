class macunit_test extends uvm_test;

    `uvm_component_utils(macunit_test)

    macunit_env env;

    function new(string name = "macunit_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = macunit_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        macunit_sequence seq;

        phase.raise_objection(this);

        seq = macunit_sequence::type_id::create("seq");

        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask

endclass