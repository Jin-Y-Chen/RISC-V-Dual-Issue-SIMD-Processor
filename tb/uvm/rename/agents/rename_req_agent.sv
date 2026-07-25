class rename_req_item extends rv_base_seq_item;
  rand bit          flush;
  rand bit          valid_rn[2];
  rand bit          spec_en[2];
  rand bit          lane_sel[2];
  rand bit          reg_write[2];
  rand bit          store_en[2];
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
  prf_addr_t         rob_idx[2];

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
    vif.req_drv_cb.flush           <= 1'b0;
    vif.req_drv_cb.spec0_en_rn     <= 1'b0;
    vif.req_drv_cb.spec1_en_rn     <= 1'b0;
    vif.req_drv_cb.i0_valid_rn     <= 1'b0;
    vif.req_drv_cb.i1_valid_rn     <= 1'b0;
    vif.req_drv_cb.i0_lane_sel_rn  <= 1'b0;
    vif.req_drv_cb.i1_lane_sel_rn  <= 1'b0;
    vif.req_drv_cb.i0_reg_write_rn <= 1'b0;
    vif.req_drv_cb.i1_reg_write_rn <= 1'b0;
    vif.req_drv_cb.i0_store_en_rn  <= 1'b0;
    vif.req_drv_cb.i1_store_en_rn  <= 1'b0;
    vif.req_drv_cb.i0_rs1_use_rn   <= 1'b0;
    vif.req_drv_cb.i0_rs2_use_rn   <= 1'b0;
    vif.req_drv_cb.i1_rs1_use_rn   <= 1'b0;
    vif.req_drv_cb.i1_rs2_use_rn   <= 1'b0;
    vif.req_drv_cb.i0_opcode_rn    <= '0;
    vif.req_drv_cb.i1_opcode_rn    <= '0;
    vif.req_drv_cb.i0_funct3_rn    <= '0;
    vif.req_drv_cb.i1_funct3_rn    <= '0;
    vif.req_drv_cb.i0_funct7_rn    <= '0;
    vif.req_drv_cb.i1_funct7_rn    <= '0;
    vif.req_drv_cb.i0_rd_addr_rn   <= '0;
    vif.req_drv_cb.i0_rs1_addr_rn  <= '0;
    vif.req_drv_cb.i0_rs2_addr_rn  <= '0;
    vif.req_drv_cb.i1_rd_addr_rn   <= '0;
    vif.req_drv_cb.i1_rs1_addr_rn  <= '0;
    vif.req_drv_cb.i1_rs2_addr_rn  <= '0;
    vif.req_drv_cb.i0_imm_rn       <= '0;
    vif.req_drv_cb.i1_imm_rn       <= '0;
    vif.req_drv_cb.i0_pc_rn        <= '0;
    vif.req_drv_cb.i1_pc_rn        <= '0;
  endtask

  task drive(rename_req_item t);
    vif.req_drv_cb.flush           <= t.flush;
    vif.req_drv_cb.spec0_en_rn     <= t.spec_en[0];
    vif.req_drv_cb.spec1_en_rn     <= t.spec_en[1];
    vif.req_drv_cb.i0_valid_rn     <= t.valid_rn[0];
    vif.req_drv_cb.i1_valid_rn     <= t.valid_rn[1];
    vif.req_drv_cb.i0_lane_sel_rn  <= t.lane_sel[0];
    vif.req_drv_cb.i1_lane_sel_rn  <= t.lane_sel[1];
    vif.req_drv_cb.i0_reg_write_rn <= t.reg_write[0];
    vif.req_drv_cb.i1_reg_write_rn <= t.reg_write[1];
    vif.req_drv_cb.i0_store_en_rn  <= t.store_en[0];
    vif.req_drv_cb.i1_store_en_rn  <= t.store_en[1];
    vif.req_drv_cb.i0_rs1_use_rn   <= t.rs1_use[0];
    vif.req_drv_cb.i0_rs2_use_rn   <= t.rs2_use[0];
    vif.req_drv_cb.i1_rs1_use_rn   <= t.rs1_use[1];
    vif.req_drv_cb.i1_rs2_use_rn   <= t.rs2_use[1];
    vif.req_drv_cb.i0_opcode_rn    <= t.opcode[0];
    vif.req_drv_cb.i1_opcode_rn    <= t.opcode[1];
    vif.req_drv_cb.i0_funct3_rn    <= t.funct3[0];
    vif.req_drv_cb.i1_funct3_rn    <= t.funct3[1];
    vif.req_drv_cb.i0_funct7_rn    <= t.funct7[0];
    vif.req_drv_cb.i1_funct7_rn    <= t.funct7[1];
    vif.req_drv_cb.i0_rd_addr_rn   <= t.rd[0];
    vif.req_drv_cb.i0_rs1_addr_rn  <= t.rs1[0];
    vif.req_drv_cb.i0_rs2_addr_rn  <= t.rs2[0];
    vif.req_drv_cb.i1_rd_addr_rn   <= t.rd[1];
    vif.req_drv_cb.i1_rs1_addr_rn  <= t.rs1[1];
    vif.req_drv_cb.i1_rs2_addr_rn  <= t.rs2[1];
    vif.req_drv_cb.i0_imm_rn       <= t.imm[0];
    vif.req_drv_cb.i1_imm_rn       <= t.imm[1];
    vif.req_drv_cb.i0_pc_rn        <= t.pc[0];
    vif.req_drv_cb.i1_pc_rn        <= t.pc[1];
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
      t.spec_en[0] = vif.mon_cb.spec0_en_rn;
      t.spec_en[1] = vif.mon_cb.spec1_en_rn;
      t.valid_rn[0] = vif.mon_cb.i0_valid_rn;
      t.valid_rn[1] = vif.mon_cb.i1_valid_rn;
      t.lane_sel[0] = vif.mon_cb.i0_lane_sel_rn;
      t.lane_sel[1] = vif.mon_cb.i1_lane_sel_rn;
      t.reg_write[0] = vif.mon_cb.i0_reg_write_rn;
      t.reg_write[1] = vif.mon_cb.i1_reg_write_rn;
      t.store_en[0] = vif.mon_cb.i0_store_en_rn;
      t.store_en[1] = vif.mon_cb.i1_store_en_rn;
      t.rs1_use[0] = vif.mon_cb.i0_rs1_use_rn;
      t.rs1_use[1] = vif.mon_cb.i1_rs1_use_rn;
      t.rs2_use[0] = vif.mon_cb.i0_rs2_use_rn;
      t.rs2_use[1] = vif.mon_cb.i1_rs2_use_rn;
      t.opcode[0] = vif.mon_cb.i0_opcode_rn;
      t.opcode[1] = vif.mon_cb.i1_opcode_rn;
      t.funct3[0] = vif.mon_cb.i0_funct3_rn;
      t.funct3[1] = vif.mon_cb.i1_funct3_rn;
      t.funct7[0] = vif.mon_cb.i0_funct7_rn;
      t.funct7[1] = vif.mon_cb.i1_funct7_rn;
      t.rd[0] = vif.mon_cb.i0_rd_addr_rn;
      t.rd[1] = vif.mon_cb.i1_rd_addr_rn;
      t.rs1[0] = vif.mon_cb.i0_rs1_addr_rn;
      t.rs1[1] = vif.mon_cb.i1_rs1_addr_rn;
      t.rs2[0] = vif.mon_cb.i0_rs2_addr_rn;
      t.rs2[1] = vif.mon_cb.i1_rs2_addr_rn;
      t.imm[0] = vif.mon_cb.i0_imm_rn;
      t.imm[1] = vif.mon_cb.i1_imm_rn;
      t.pc[0] = vif.mon_cb.i0_pc_rn;
      t.pc[1] = vif.mon_cb.i1_pc_rn;
      t.stall = vif.mon_cb.stall_id;
      t.valid[0] = vif.mon_cb.i0_valid_disp;
      t.valid[1] = vif.mon_cb.i1_valid_disp;
      t.ps1[0] = vif.mon_cb.i0_ps1_disp;
      t.ps1[1] = vif.mon_cb.i1_ps1_disp;
      t.ps2[0] = vif.mon_cb.i0_ps2_disp;
      t.ps2[1] = vif.mon_cb.i1_ps2_disp;
      t.prd[0] = vif.mon_cb.i0_prd_disp;
      t.prd[1] = vif.mon_cb.i1_prd_disp;
      t.rob_idx[0] = vif.mon_cb.i0_rob_idx_disp;
      t.rob_idx[1] = vif.mon_cb.i1_rob_idx_disp;
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
