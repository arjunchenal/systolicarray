// Environment -> connects agent and scoreboard


class macunit_env extends uvm_env;

    `uvm_component_utils(macunit_env)

    macunit_agent agent;
    macunit_scoreboard scoreboard;

    function new(string name="macunit_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = macunit_agent::type_id::create("agent", this);
        scoreboard = macunit_scoreboard::type_id::create("scoreboard", this);

    endfunction

    function void connect_phase(uvm_phase phase);  // where we connect UVM ports
        super.connect_phase(phase);

        agent.monitor.monitor_ap.connect(scoreboard.scoreboard_imp);
    endfunction


endclass