class rename_base_test extends uvm_test;
  `uvm_component_utils(rename_base_test)

  rename_env env;
  rename_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual rename_if vif;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rename_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "rename_if was not provided by tb_top")
    cfg = rename_env_cfg::type_id::create("cfg");
    cfg.vif = vif;
    uvm_config_db#(rename_env_cfg)::set(this, "env", "cfg", cfg);
    env = rename_env::type_id::create("env", this);
  endfunction

  task wait_for_reset();
    wait (cfg.vif.rst_n === 1'b1);
    @(negedge cfg.vif.clk);
  endtask
endclass

class rename_smoke_test extends rename_base_test;
  `uvm_component_utils(rename_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_smoke_seq req_seq = rename_smoke_seq::type_id::create("req_seq");
    rename_wb_smoke_seq wb_seq = rename_wb_smoke_seq::type_id::create("wb_seq");
    phase.raise_objection(this);
    wait_for_reset();
    fork
      req_seq.start(env.req_agent.sequencer);
      wb_seq.start(env.wb_agent.sequencer);
    join
    repeat (3) @(negedge cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class rename_random_test extends rename_base_test;
  `uvm_component_utils(rename_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_random_seq req_seq = rename_random_seq::type_id::create("req_seq");
    rename_wb_random_seq wb_seq = rename_wb_random_seq::type_id::create("wb_seq");
    phase.raise_objection(this);
    wait_for_reset();
    req_seq.num_pairs = 100;
    wb_seq.num_pairs = req_seq.num_pairs;
    fork
      req_seq.start(env.req_agent.sequencer);
      wb_seq.start(env.wb_agent.sequencer);
    join
    repeat (4) @(negedge cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class rename_flush_test extends rename_base_test;
  `uvm_component_utils(rename_flush_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_flush_seq req_seq = rename_flush_seq::type_id::create("req_seq");
    rename_wb_flush_seq wb_seq = rename_wb_flush_seq::type_id::create("wb_seq");
    phase.raise_objection(this);
    wait_for_reset();
    fork
      req_seq.start(env.req_agent.sequencer);
      wb_seq.start(env.wb_agent.sequencer);
    join
    repeat (3) @(negedge cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class rename_raw_hazard_test extends rename_base_test;
  `uvm_component_utils(rename_raw_hazard_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_raw_hazard_seq req_seq =
      rename_raw_hazard_seq::type_id::create("req_seq");
    rename_wb_smoke_seq wb_seq =
      rename_wb_smoke_seq::type_id::create("wb_seq");
    phase.raise_objection(this);
    wait_for_reset();
    fork
      req_seq.start(env.req_agent.sequencer);
      wb_seq.start(env.wb_agent.sequencer);
    join
    repeat (3) @(negedge cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class rename_branch_test extends rename_base_test;
  `uvm_component_utils(rename_branch_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_branch_seq req_seq = rename_branch_seq::type_id::create("req_seq");
    rename_wb_branch_seq wb_seq =
      rename_wb_branch_seq::type_id::create("wb_seq");
    phase.raise_objection(this);
    wait_for_reset();
    fork
      req_seq.start(env.req_agent.sequencer);
      wb_seq.start(env.wb_agent.sequencer);
    join
    repeat (3) @(negedge cfg.vif.clk);
    phase.drop_objection(this);
  endtask
endclass
