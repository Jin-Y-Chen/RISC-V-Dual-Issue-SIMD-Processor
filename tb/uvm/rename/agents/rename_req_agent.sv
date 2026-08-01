class rename_req_item extends rv_base_seq_item;
  rand bit          flush;
  rand bit          valid_rn[2];
  rand bit          spec_en[2];
  rand bit          lane_sel[2];
  rand bit          reg_write[2];
  rand bit          store_en[2];
  rand bit          brch_en[2];
  rand bit          state_valid[2];
  rand br_state_t   brch_state[2];
  rand bit          rs1_use[2];
  rand bit          rs2_use[2];
  rand opcode_t     opcode[2];
  rand funct3_t     funct3[2];
  rand funct7_t     funct7[2];
  rand gpr_addr_t   rd[2];
  rand gpr_addr_t   rs1[2];
  rand gpr_addr_t   rs2[2];
  rand word_t       imm[2];
  rand word_t       pc[2];

  logic             rst_n;
  logic             stall;
  logic             valid[2];
  prf_addr_t        ps1[2], ps2[2], prd[2];
  prf_addr_t        rob_tag[2];  // refmodel-only: expected ROB slot for scoreboard

  constraint c_reset { flush dist {0 := 99, 1 := 1}; }
  constraint c_regs  {
    foreach (rd[i])  rd[i]  inside {[0:31]};
    foreach (rs1[i]) rs1[i] inside {[0:31]};
    foreach (rs2[i]) rs2[i] inside {[0:31]};
  }
  constraint c_opcode {
    foreach (opcode[i])
      opcode[i] inside {7'b0, OPC_OP, OPC_OP_IMM, OPC_LOAD, OPC_STORE,
                        OPC_BRANCH, OPC_JAL, OPC_JALR, OPC_AUIPC, OPC_LUI};
  }
  // Match decode_brch_en: BRANCH / JAL / JALR
  constraint c_brch_en {
    foreach (brch_en[i])
      brch_en[i] == (opcode[i] inside {OPC_BRANCH, OPC_JAL, OPC_JALR});
  }

  `uvm_object_utils(rename_req_item)

  function new(string name = "rename_req_item");
    super.new(name);
  endfunction
endclass

class rename_req_agent_cfg extends uvm_object;
  `uvm_object_utils(rename_req_agent_cfg)
  virtual rename_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name = "rename_req_agent_cfg");
    super.new(name);
  endfunction
endclass

class rename_req_sequencer extends uvm_sequencer #(rename_req_item);
  `uvm_component_utils(rename_req_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class rename_req_driver extends rv_base_driver #(rename_req_item);
  `uvm_component_utils(rename_req_driver)
  virtual rename_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_req_item item;
    forever begin
      seq_item_port.get_next_item(item);
      @(vif.req_drv_cb);
      drive(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.req_drv_cb.flush <= 1'b0;
    foreach (vif.req_drv_cb.spec_en_rn[i]) begin
      vif.req_drv_cb.spec_en_rn[i]     <= 1'b0;
      vif.req_drv_cb.valid_rn[i]       <= 1'b0;
      vif.req_drv_cb.reg_write_rn[i]   <= 1'b0;
      vif.req_drv_cb.store_en_rn[i]    <= 1'b0;
      vif.req_drv_cb.brch_en_rn[i]     <= 1'b0;
      vif.req_drv_cb.state_valid_rn[i] <= 1'b0;
      vif.req_drv_cb.brch_state_rn[i]  <= '0;
      vif.req_drv_cb.rs1_use_rn[i]     <= 1'b0;
      vif.req_drv_cb.rs2_use_rn[i]     <= 1'b0;
      vif.req_drv_cb.rd_addr_rn[i]     <= '0;
      vif.req_drv_cb.rs1_addr_rn[i]    <= '0;
      vif.req_drv_cb.rs2_addr_rn[i]    <= '0;
    end
  endtask

  task drive(rename_req_item t);
    vif.req_drv_cb.flush <= t.flush;
    foreach (t.valid_rn[i]) begin
      vif.req_drv_cb.spec_en_rn[i]     <= t.spec_en[i];
      vif.req_drv_cb.valid_rn[i]       <= t.valid_rn[i];
      vif.req_drv_cb.reg_write_rn[i]   <= t.reg_write[i];
      vif.req_drv_cb.store_en_rn[i]    <= t.store_en[i];
      vif.req_drv_cb.brch_en_rn[i]     <= (t.opcode[i] inside {OPC_BRANCH, OPC_JAL, OPC_JALR});
      vif.req_drv_cb.state_valid_rn[i] <= t.state_valid[i];
      vif.req_drv_cb.brch_state_rn[i]  <= t.brch_state[i];
      vif.req_drv_cb.rs1_use_rn[i]     <= t.rs1_use[i];
      vif.req_drv_cb.rs2_use_rn[i]     <= t.rs2_use[i];
      vif.req_drv_cb.rd_addr_rn[i]     <= t.rd[i];
      vif.req_drv_cb.rs1_addr_rn[i]    <= t.rs1[i];
      vif.req_drv_cb.rs2_addr_rn[i]    <= t.rs2[i];
    end
  endtask
endclass

class rename_req_monitor extends rv_base_monitor #(rename_req_item);
  `uvm_component_utils(rename_req_monitor)
  virtual rename_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rename_req_item t;
    forever begin
      @(vif.mon_cb);
      t = rename_req_item::type_id::create("t");
      t.rst_n = vif.mon_cb.rst_n;
      t.flush = vif.mon_cb.flush;
      foreach (t.valid_rn[i]) begin
        t.spec_en[i]     = vif.mon_cb.spec_en_rn[i];
        t.valid_rn[i]    = vif.mon_cb.valid_rn[i];
        t.reg_write[i]   = vif.mon_cb.reg_write_rn[i];
        t.store_en[i]    = vif.mon_cb.store_en_rn[i];
        t.brch_en[i]     = vif.mon_cb.brch_en_rn[i];
        t.state_valid[i] = vif.mon_cb.state_valid_rn[i];
        t.brch_state[i]  = vif.mon_cb.brch_state_rn[i];
        t.rs1_use[i]     = vif.mon_cb.rs1_use_rn[i];
        t.rs2_use[i]     = vif.mon_cb.rs2_use_rn[i];
        t.rd[i]          = vif.mon_cb.rd_addr_rn[i];
        t.rs1[i]         = vif.mon_cb.rs1_addr_rn[i];
        t.rs2[i]         = vif.mon_cb.rs2_addr_rn[i];
        t.valid[i]       = vif.mon_cb.valid_rs[i];
        t.ps1[i]         = vif.mon_cb.ps1_tag_rs[i];
        t.ps2[i]         = vif.mon_cb.ps2_tag_rs[i];
        t.prd[i]         = vif.mon_cb.rob_tag_rs[i];
      end
      t.stall = vif.mon_cb.stall;
      ap.write(t);
    end
  endtask
endclass

class rename_req_agent extends rv_base_agent #(rename_req_item);
  `uvm_component_utils(rename_req_agent)
  rename_req_agent_cfg cfg;
  rename_req_driver driver;
  rename_req_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(rename_req_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "rename request agent config is missing")
    is_active = cfg.is_active;
    super.build_phase(phase);
    monitor = rename_req_monitor::type_id::create("monitor", this);
    monitor.vif = cfg.vif;
    if (is_active == UVM_ACTIVE) begin
      driver = rename_req_driver::type_id::create("driver", this);
      driver.vif = cfg.vif;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
