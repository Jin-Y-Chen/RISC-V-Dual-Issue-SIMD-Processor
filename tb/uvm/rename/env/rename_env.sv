class rename_env extends uvm_env;
  `uvm_component_utils(rename_env)

  rename_env_cfg cfg;
  rename_req_agent req_agent;
  rename_wb_agent wb_agent;
  rename_scoreboard scoreboard;
  rename_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    rename_req_agent_cfg req_cfg;
    rename_wb_agent_cfg wb_cfg;

    super.build_phase(phase);
    if (!uvm_config_db#(rename_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "rename environment config is missing")

    req_cfg = rename_req_agent_cfg::type_id::create("req_cfg");
    req_cfg.vif = cfg.vif;
    req_cfg.is_active = cfg.req_is_active;
    uvm_config_db#(rename_req_agent_cfg)::set(this, "req_agent", "cfg", req_cfg);

    wb_cfg = rename_wb_agent_cfg::type_id::create("wb_cfg");
    wb_cfg.vif = cfg.vif;
    wb_cfg.is_active = cfg.wb_is_active;
    uvm_config_db#(rename_wb_agent_cfg)::set(this, "wb_agent", "cfg", wb_cfg);

    req_agent = rename_req_agent::type_id::create("req_agent", this);
    wb_agent = rename_wb_agent::type_id::create("wb_agent", this);
    scoreboard = rename_scoreboard::type_id::create("scoreboard", this);
    if (cfg.coverage_enable)
      coverage = rename_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    req_agent.monitor.ap.connect(scoreboard.req_imp);
    wb_agent.monitor.ap.connect(scoreboard.wb_imp);
    if (coverage != null)
      req_agent.monitor.ap.connect(coverage.analysis_export);
  endfunction
endclass
