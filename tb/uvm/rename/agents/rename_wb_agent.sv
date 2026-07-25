class rename_wb_item extends rv_base_seq_item;
  rand bit         wback_en[2];
  rand prf_addr_t  rob_idx[2];
  rand bit         branch_taken[2];

  logic            rst_n;
  logic            flush;
  logic            commit_en[2];
  logic            retire_en[2];
  gpr_addr_t       commit_rd[2];
  prf_addr_t       commit_prd[2];

  `uvm_object_utils(rename_wb_item)

  function new(string name = "rename_wb_item");
    super.new(name);
  endfunction
endclass

class rename_wb_agent_cfg extends uvm_object;
  `uvm_object_utils(rename_wb_agent_cfg)
  virtual rename_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name = "rename_wb_agent_cfg");
    super.new(name);
  endfunction
endclass

class rename_wb_sequencer extends uvm_sequencer #(rename_wb_item);
  `uvm_component_utils(rename_wb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class rename_wb_driver extends rv_base_driver #(rename_wb_item);
  `uvm_component_utils(rename_wb_driver)
  virtual rename_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_wb_item item;
    forever begin
      seq_item_port.get_next_item(item);
      @(vif.wb_drv_cb);
      drive(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.wb_drv_cb.wback0_en            <= 1'b0;
    vif.wb_drv_cb.wback1_en            <= 1'b0;
    vif.wb_drv_cb.i0_rob_idx_wb            <= '0;
    vif.wb_drv_cb.i1_rob_idx_wb            <= '0;
    vif.wb_drv_cb.i0_brch_taken_wb     <= 1'b0;
    vif.wb_drv_cb.i1_brch_taken_wb     <= 1'b0;
  endtask

  task drive(rename_wb_item t);
    vif.wb_drv_cb.wback0_en            <= t.wback_en[0];
    vif.wb_drv_cb.wback1_en            <= t.wback_en[1];
    vif.wb_drv_cb.i0_rob_idx_wb            <= t.rob_idx[0];
    vif.wb_drv_cb.i1_rob_idx_wb            <= t.rob_idx[1];
    vif.wb_drv_cb.i0_brch_taken_wb     <= t.branch_taken[0];
    vif.wb_drv_cb.i1_brch_taken_wb     <= t.branch_taken[1];
  endtask
endclass

class rename_wb_monitor extends rv_base_monitor #(rename_wb_item);
  `uvm_component_utils(rename_wb_monitor)
  virtual rename_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_wb_item t;
    forever begin
      @(vif.mon_cb);
      t = rename_wb_item::type_id::create("t");
      t.rst_n = vif.mon_cb.rst_n;
      t.flush = vif.mon_cb.flush;
      t.wback_en[0] = vif.mon_cb.wback0_en;
      t.wback_en[1] = vif.mon_cb.wback1_en;
      t.rob_idx[0] = vif.mon_cb.i0_rob_idx_wb;
      t.rob_idx[1] = vif.mon_cb.i1_rob_idx_wb;
      t.branch_taken[0] = vif.mon_cb.i0_brch_taken_wb;
      t.branch_taken[1] = vif.mon_cb.i1_brch_taken_wb;
      t.commit_en[0] = vif.mon_cb.rrat0_en;
      t.commit_en[1] = vif.mon_cb.rrat1_en;
      t.commit_rd[0] = vif.mon_cb.i0_rd_addr_cmt;
      t.commit_rd[1] = vif.mon_cb.i1_rd_addr_cmt;
      t.commit_prd[0] = vif.mon_cb.i0_rob_idx_cmt;
      t.commit_prd[1] = vif.mon_cb.i1_rob_idx_cmt;
      t.retire_en[0] = vif.mon_cb.retire0_en;
      t.retire_en[1] = vif.mon_cb.retire1_en;
      ap.write(t);
    end
  endtask
endclass

class rename_wb_agent extends rv_base_agent #(rename_wb_item);
  `uvm_component_utils(rename_wb_agent)
  rename_wb_agent_cfg cfg;
  rename_wb_driver driver;
  rename_wb_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(rename_wb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "rename writeback agent config is missing")
    is_active = cfg.is_active;
    super.build_phase(phase);
    monitor = rename_wb_monitor::type_id::create("monitor", this);
    monitor.vif = cfg.vif;
    if (is_active == UVM_ACTIVE) begin
      driver = rename_wb_driver::type_id::create("driver", this);
      driver.vif = cfg.vif;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
