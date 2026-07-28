`timescale 1ns / 1ps

// RV-DIS scalar OoO core:
//   fetch → decode → id_rn → rename → rn_dp → issue (RS+PRF+dp_ex)
//         → execute lanes → ex_mem → memory → ex_mem_wb → PRF/ROB complete
import rv_dis_pkg::*;

module risc_dis_unit #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  output word_t       pc_fetch,
  output word_t       pc_fetch_plus4,
  output logic        stall_id
);

  logic flush_core;
  logic br_recover;
  logic stall_rn;
  logic stall_dp;
  logic stall_ex;

  // -------------------------------------------------------------------------
  // Fetch / IF-ID  ([2]: index 0 = I0, 1 = I1)
  // -------------------------------------------------------------------------
  logic        pred_taken      [2];
  logic        brch_recover    [2];
  word_t       pc_execute      [2];
  word_t       pc_if           [2];
  word_t       pc_target_if    [2];
  instr_t      instr_if        [2];
  logic        valid_if        [2];
  logic        target_valid_if [2];
  logic        spec_en_if      [2];

  instr_t      instr_id        [2];
  word_t       pc_id           [2];
  word_t       pc_target_id    [2];
  logic        fetch_valid_id  [2];
  logic        target_valid_id [2];
  logic        spec_en_id      [2];

  logic        nest_spec_stall [2];
  logic        pred_valid_wb   [2];
  word_t       pc_predict      [2];

  // MEM branch resolve → BHT train / fetch recover (BTB train is decode pred_valid_wb)
  word_t       brch_pc_wb      [2];
  br_state_t   brch_state_wb   [2];

  // Declared early: MEM-stage branch taken feeds fetch recover / rename / BHT
  logic        od0_brch_taken_mem, od1_brch_taken_mem;

  assign pc_fetch      = pc_if[0];
  assign pc_fetch_plus4 = pc_if[1];

  s1_fetch_struct #(
    .RESET_PC(RESET_PC)
  ) u_fetch (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .dispatch_stall (stall_id),
    .spec_stall     (nest_spec_stall),
    .pred_taken     (pred_taken),
    .brch_recover   (brch_recover),
    .valid_wb       (pred_valid_wb),
    .pc_execute     (pc_execute),
    .pc_wb          (pc_id),
    .pc_target_wb   (pc_predict),
    .pc_if          (pc_if),
    .pc_target      (pc_target_if),
    .instr          (instr_if),
    .spec_en        (spec_en_if),
    .valid          (valid_if),
    .target_valid   (target_valid_if)
  );

  if_id u_if_id (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .flush           (flush_core),
    .stall           (stall_id),
    .fetch_valid_if  (valid_if),
    .target_valid_if (target_valid_if),
    .spec_en_if      (spec_en_if),
    .instr_if        (instr_if),
    .pc_if           (pc_if),
    .pc_target_if    (pc_target_if),
    .instr_id        (instr_id),
    .pc_id           (pc_id),
    .pc_target_id    (pc_target_id),
    .fetch_valid_id  (fetch_valid_id),
    .target_valid_id (target_valid_id),
    .spec_en_id      (spec_en_id)
  );

  // -------------------------------------------------------------------------
  // Decode  ([2] arrays through id_rn; rename still scalar dual-slot)
  // -------------------------------------------------------------------------
  logic        valid_dec     [2];
  logic        store_en_dec  [2];
  logic        brch_en_dec   [2];
  logic        lane_sel_dec  [2];
  opcode_t     opcode_dec    [2];
  funct3_t     funct3_dec    [2];
  funct7_t     funct7_dec    [2];
  gpr_addr_t   rd_addr_dec   [2];
  gpr_addr_t   rs1_addr_dec  [2];
  gpr_addr_t   rs2_addr_dec  [2];
  word_t       imm_dec       [2];
  logic        rs1_use_dec   [2];
  logic        rs2_use_dec   [2];
  logic        reg_write_dec [2];
  br_state_t   brch_state    [2];
  logic        state_valid_dec [2];

  s2_decode_struct u_decode (
    .clk             (clk),
    .rst_n           (rst_n),
    .fetch_valid_id  (fetch_valid_id),
    .spec_en_id      (spec_en_id),
    .instr_id        (instr_id),
    .pc_id           (pc_id),
    .pc_target_id    (pc_target_id),
    .target_valid_id (target_valid_id),
    .brch_valid_wb   (brch_recover),
    .brch_pc_wb      (brch_pc_wb),
    .brch_state_wb   (brch_state_wb),
    .lane_sel        (lane_sel_dec),
    .opcode          (opcode_dec),
    .funct3          (funct3_dec),
    .funct7          (funct7_dec),
    .rd_addr         (rd_addr_dec),
    .rs1_addr        (rs1_addr_dec),
    .rs2_addr        (rs2_addr_dec),
    .imm             (imm_dec),
    .valid           (valid_dec),
    .brch_en         (brch_en_dec),
    .store_en        (store_en_dec),
    .rs1_use         (rs1_use_dec),
    .rs2_use         (rs2_use_dec),
    .reg_write       (reg_write_dec),
    .brch_state      (brch_state),
    .state_valid     (state_valid_dec),
    .pc_predict      (pc_predict),
    .pred_taken      (pred_taken),
    .pred_valid_wb   (pred_valid_wb),
    .nest_spec_stall (nest_spec_stall)
  );

  // -------------------------------------------------------------------------
  // ID/RN → Rename → RN/DP → Issue
  // -------------------------------------------------------------------------
  // id_rn / rename / rn_dp / issue use [2] arrays; EX demux stays ev*/od*.
  logic        valid_rn     [2];
  logic        lane_sel_rn  [2];
  logic        reg_write_rn [2];
  logic        store_en_rn  [2];
  logic        brch_en_rn   [2];
  logic        state_valid_rn [2];
  br_state_t   brch_state_rn  [2];
  logic        rs1_use_rn   [2];
  logic        rs2_use_rn   [2];
  logic        spec_en_rn   [2];
  opcode_t     opcode_rn    [2];
  funct3_t     funct3_rn    [2];
  funct7_t     funct7_rn    [2];
  gpr_addr_t   rd_addr_rn   [2];
  gpr_addr_t   rs1_addr_rn  [2];
  gpr_addr_t   rs2_addr_rn  [2];
  word_t       imm_rn       [2];
  word_t       pc_rn        [2];

  logic        valid_rs       [2];
  logic        spec_en_rs     [2];
  prf_addr_t   ps1_tag_rs     [2];
  prf_addr_t   ps2_tag_rs     [2];
  logic        tag1_valid_rs  [2];
  logic        tag2_valid_rs  [2];
  prf_addr_t   rob_tag_rs     [2];

  logic        wback_en       [2];
  prf_addr_t   rob_tag_wb     [2];
  logic        brch_taken_wb   [2];

  logic        rob_valid_dp   [2];
  logic        lane_sel_dp    [2];
  logic        spec_en_dp     [2];
  opcode_t     opcode_dp      [2];
  funct3_t     funct3_dp      [2];
  funct7_t     funct7_dp      [2];
  prf_addr_t   ps1_tag_dp     [2];
  prf_addr_t   ps2_tag_dp     [2];
  logic        tag1_valid_dp  [2];
  logic        tag2_valid_dp  [2];
  prf_addr_t   rob_tag_dp     [2];
  word_t       imm_dp         [2];
  word_t       pc_dp          [2];

  logic        ev_enable_ex    [2];
  logic        ev_reg_write_ex [2];
  opcode_t     ev_opcode_ex    [2];
  funct3_t     ev_funct3_ex    [2];
  funct7_t     ev_funct7_ex    [2];
  prf_addr_t   ev_prd_ex       [2];
  word_t       ev_imm_ex       [2];
  word_t       ev_pc_ex        [2];
  word_t       ev_rs1_data_ex  [2];
  word_t       ev_rs2_data_ex  [2];

  logic        od_enable_ex    [2];
  logic        od_reg_write_ex [2];
  opcode_t     od_opcode_ex    [2];
  funct3_t     od_funct3_ex    [2];
  prf_addr_t   od_prd_ex       [2];
  word_t       od_imm_ex       [2];
  word_t       od_pc_ex        [2];
  word_t       od_rs1_data_ex  [2];
  word_t       od_rs2_data_ex  [2];

  // WB push bundle (ex_mem_wb → PRF wakeup + ROB mark-done)
  logic        wb_push0_valid, wb_push1_valid;
  prf_addr_t   wb_push0_rd_addr, wb_push1_rd_addr;
  logic [31:0] wb_push0_wdata, wb_push1_wdata;

  logic        wb_en_iss   [2];
  word_t       wb_data_iss [2];

  assign wb_en_iss[0]   = wb_push0_valid;
  assign wb_en_iss[1]   = wb_push1_valid;
  assign wb_data_iss[0] = wb_push0_wdata;
  assign wb_data_iss[1] = wb_push1_wdata;

  id_rn u_id_rn (
    .clk          (clk),
    .rst_n        (rst_n),
    .enable       (enable),
    .flush        (flush_core),
    .stall        (stall_id),
    .decode_valid_id (valid_dec),
    .lane_sel_id     (lane_sel_dec),
    .reg_write_id    (reg_write_dec),
    .store_en_id     (store_en_dec),
    .brch_en_id      (brch_en_dec),
    .state_valid_id  (state_valid_dec),
    .brch_state_id   (brch_state),
    .rs1_use_id      (rs1_use_dec),
    .rs2_use_id      (rs2_use_dec),
    .spec_en_id      (spec_en_id),
    .opcode_id       (opcode_dec),
    .funct3_id       (funct3_dec),
    .funct7_id       (funct7_dec),
    .rd_addr_id      (rd_addr_dec),
    .rs1_addr_id     (rs1_addr_dec),
    .rs2_addr_id     (rs2_addr_dec),
    .imm_id          (imm_dec),
    .pc_id           (pc_id),
    .valid_rn        (valid_rn),
    .lane_sel_rn     (lane_sel_rn),
    .reg_write_rn    (reg_write_rn),
    .store_en_rn     (store_en_rn),
    .brch_en_rn      (brch_en_rn),
    .state_valid_rn  (state_valid_rn),
    .brch_state_rn   (brch_state_rn),
    .rs1_use_rn      (rs1_use_rn),
    .rs2_use_rn      (rs2_use_rn),
    .spec_en_rn      (spec_en_rn),
    .opcode_rn       (opcode_rn),
    .funct3_rn       (funct3_rn),
    .funct7_rn       (funct7_rn),
    .rd_addr_rn      (rd_addr_rn),
    .rs1_addr_rn     (rs1_addr_rn),
    .rs2_addr_rn     (rs2_addr_rn),
    .imm_rn          (imm_rn),
    .pc_rn           (pc_rn)
  );

  assign wback_en[0]       = wb_push0_valid;
  assign wback_en[1]       = wb_push1_valid;
  assign rob_tag_wb[0]     = wb_push0_rd_addr;
  assign rob_tag_wb[1]     = wb_push1_rd_addr;
  assign brch_taken_wb[0]  = od0_brch_taken_mem;
  assign brch_taken_wb[1]  = od1_brch_taken_mem;


  rename_core_struct u_rename (
    .clk               (clk),
    .rst_n             (rst_n),
    .flush             (flush_core),
    .stall_rn          (stall_rn),
    .enable            (enable),
    .spec_en_rn        (spec_en_rn),
    .valid_rn          (valid_rn),
    .reg_write_rn      (reg_write_rn),
    .store_en_rn       (store_en_rn),
    .brch_en_rn        (brch_en_rn),
    .state_valid_rn    (state_valid_rn),
    .brch_state_rn     (brch_state_rn),
    .rs1_use_rn        (rs1_use_rn),
    .rs2_use_rn        (rs2_use_rn),
    .rd_addr_rn        (rd_addr_rn),
    .rs1_addr_rn       (rs1_addr_rn),
    .rs2_addr_rn       (rs2_addr_rn),
    .wback_en          (wback_en),
    .rob_tag_wb        (rob_tag_wb),
    .brch_taken_wb     (brch_taken_wb),
    .stall             (stall_id),
    .valid_rs          (valid_rs),
    .spec_en_rs        (spec_en_rs),
    .ps1_tag_rs        (ps1_tag_rs),
    .ps2_tag_rs        (ps2_tag_rs),
    .tag1_valid_rs     (tag1_valid_rs),
    .tag2_valid_rs     (tag2_valid_rs),
    .rob_tag_rs        (rob_tag_rs)
  );

  // Decode payload bypasses rename (ROB stall holds id_rn aligned with valid_rs).
  rn_dp u_rn_dp (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .flush           (flush_core),
    .stall_dp        (stall_dp),
    .stall_rn        (stall_rn),
    .rob_valid_rn    (valid_rs),
    .lane_sel_rn     (lane_sel_rn),
    .spec_en_rn      (spec_en_rs),
    .opcode_rn       (opcode_rn),
    .funct3_rn       (funct3_rn),
    .funct7_rn       (funct7_rn),
    .ps1_tag_rn      (ps1_tag_rs),
    .ps2_tag_rn      (ps2_tag_rs),
    .tag1_valid_rn   (tag1_valid_rs),
    .tag2_valid_rn   (tag2_valid_rs),
    .rob_tag_rn      (rob_tag_rs),
    .imm_rn          (imm_rn),
    .pc_rn           (pc_rn),
    .rob_valid_dp,
    .lane_sel_dp,
    .spec_en_dp,
    .opcode_dp,
    .funct3_dp,
    .funct7_dp,
    .ps1_tag_dp,
    .ps2_tag_dp,
    .tag1_valid_dp,
    .tag2_valid_dp,
    .rob_tag_dp,
    .imm_dp,
    .pc_dp
  );

  issue_core_struct u_issue (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .flush             (flush_core),
    .stall_ex          (stall_ex),
    .rob_valid_dp,
    .lane_sel_dp,
    .spec_en_dp,
    .opcode_dp,
    .funct3_dp,
    .funct7_dp,
    .ps1_tag_dp,
    .ps2_tag_dp,
    .tag1_valid_dp,
    .tag2_valid_dp,
    .rob_tag_dp,
    .imm_dp,
    .pc_dp,
    .wb_en             (wb_en_iss),
    .rob_tag_wb        (rob_tag_wb),
    .wb_data           (wb_data_iss),
    .stall_dp          (stall_dp),
    .ev_enable_ex,
    .ev_reg_write_ex,
    .ev_opcode_ex,
    .ev_funct3_ex,
    .ev_funct7_ex,
    .ev_prd_ex,
    .ev_imm_ex,
    .ev_pc_ex,
    .ev_rs1_data_ex,
    .ev_rs2_data_ex,
    .od_enable_ex,
    .od_reg_write_ex,
    .od_opcode_ex,
    .od_funct3_ex,
    .od_prd_ex,
    .od_imm_ex,
    .od_pc_ex,
    .od_rs1_data_ex,
    .od_rs2_data_ex
  );

  // -------------------------------------------------------------------------
  // Execute → MEM → WB
  // -------------------------------------------------------------------------
  word_t       ev_alu_result  [2];
  logic        od_use_link_ex [2];
  logic        od_brch_taken  [2];
  word_t       od_brch_pc     [2];
  logic        od_mem_en      [2];
  logic        od_mem_write   [2];
  word_t       od_mem_addr    [2];
  word_t       od_mem_wdata   [2];
  mem_besel_t  od_mem_besel   [2];
  word_t       od_link_pc     [2];
  word_t       od_alu_result  [2];

  logic        od0_use_link_mem, od1_use_link_mem;
  logic        od0_reg_write_mem, od1_reg_write_mem;
  prf_addr_t   od0_rd_addr_mem, od1_rd_addr_mem;
  logic [31:0] od0_brch_pc_mem, od1_brch_pc_mem;
  logic        od0_mem_en_mem, od1_mem_en_mem;
  logic        od0_mem_write_mem, od1_mem_write_mem;
  logic [31:0] od0_mem_addr_mem, od1_mem_addr_mem;
  logic [31:0] od0_mem_wdata_mem, od1_mem_wdata_mem;
  logic [3:0]  od0_mem_besel_mem, od1_mem_besel_mem;
  logic [31:0] od0_alu_result_mem, od1_alu_result_mem;
  logic [31:0] od0_pc_mem, od1_pc_mem;
  logic [31:0] od0_load_mem_data, od1_load_mem_data;
  logic        dcache_busy;

  assign stall_ex = dcache_busy;

  s4_execute_struct u_execute (
    .ev_enable_ex,
    .ev_opcode_ex,
    .ev_funct3_ex,
    .ev_funct7_ex,
    .ev_imm_ex,
    .ev_rs1_data_ex,
    .ev_rs2_data_ex,
    .od_enable_ex,
    .od_opcode_ex,
    .od_funct3_ex,
    .od_imm_ex,
    .od_pc_ex,
    .od_rs1_data_ex,
    .od_rs2_data_ex,
    .od_use_link_ex,
    .od_brch_taken,
    .od_mem_en,
    .od_mem_write,
    .ev_alu_result,
    .od_brch_pc,
    .od_mem_addr,
    .od_mem_wdata,
    .od_mem_besel,
    .od_link_pc,
    .od_alu_result
  );

  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .stall_od0           (dcache_busy && od0_mem_en_mem),
    .stall_od1           (dcache_busy && od1_mem_en_mem),
    .od0_enable_ex       (od_enable_ex[0]),
    .od0_reg_write_ex    (od_reg_write_ex[0]),
    .od0_rd_addr_ex      (od_prd_ex[0]),
    .od0_brch_taken_ex   (od_brch_taken[0]),
    .od0_brch_pc_ex      (od_brch_pc[0]),
    .od0_mem_en_ex       (od_mem_en[0]),
    .od0_mem_write_ex    (od_mem_write[0]),
    .od0_mem_addr_ex     (od_mem_addr[0]),
    .od0_mem_wdata_ex    (od_mem_wdata[0]),
    .od0_mem_besel_ex    (od_mem_besel[0]),
    .od0_link_pc_ex      (od_link_pc[0]),
    .od0_alu_result_ex   (od_alu_result[0]),
    .od0_use_link_ex     (od_use_link_ex[0]),
    .od0_pc_ex           (od_pc_ex[0]),
    .od1_enable_ex       (od_enable_ex[1]),
    .od1_reg_write_ex    (od_reg_write_ex[1]),
    .od1_rd_addr_ex      (od_prd_ex[1]),
    .od1_brch_taken_ex   (od_brch_taken[1]),
    .od1_brch_pc_ex      (od_brch_pc[1]),
    .od1_mem_en_ex       (od_mem_en[1]),
    .od1_mem_write_ex    (od_mem_write[1]),
    .od1_mem_addr_ex     (od_mem_addr[1]),
    .od1_mem_wdata_ex    (od_mem_wdata[1]),
    .od1_mem_besel_ex    (od_mem_besel[1]),
    .od1_link_pc_ex      (od_link_pc[1]),
    .od1_alu_result_ex   (od_alu_result[1]),
    .od1_use_link_ex     (od_use_link_ex[1]),
    .od1_pc_ex           (od_pc_ex[1]),
    .od0_reg_write_mem   (od0_reg_write_mem),
    .od0_rd_addr_mem     (od0_rd_addr_mem),
    .od0_brch_taken_mem  (od0_brch_taken_mem),
    .od0_brch_pc_mem     (od0_brch_pc_mem),
    .od0_mem_en_mem      (od0_mem_en_mem),
    .od0_mem_write_mem   (od0_mem_write_mem),
    .od0_mem_addr_mem    (od0_mem_addr_mem),
    .od0_mem_wdata_mem   (od0_mem_wdata_mem),
    .od0_mem_besel_mem   (od0_mem_besel_mem),
    .od0_link_pc_mem     (),
    .od0_alu_result_mem  (od0_alu_result_mem),
    .od0_use_link_mem    (od0_use_link_mem),
    .od0_pc_mem          (od0_pc_mem),
    .od1_reg_write_mem   (od1_reg_write_mem),
    .od1_rd_addr_mem     (od1_rd_addr_mem),
    .od1_brch_taken_mem  (od1_brch_taken_mem),
    .od1_brch_pc_mem     (od1_brch_pc_mem),
    .od1_mem_en_mem      (od1_mem_en_mem),
    .od1_mem_write_mem   (od1_mem_write_mem),
    .od1_mem_addr_mem    (od1_mem_addr_mem),
    .od1_mem_wdata_mem   (od1_mem_wdata_mem),
    .od1_mem_besel_mem   (od1_mem_besel_mem),
    .od1_link_pc_mem     (),
    .od1_alu_result_mem  (od1_alu_result_mem),
    .od1_use_link_mem    (od1_use_link_mem),
    .od1_pc_mem          (od1_pc_mem)
  );

  // Branch recover / flush (MEM-stage taken → fetch redirect + core flush)
  // BTB train is decode pred_valid_wb + pc_predict; BHT still trains on MEM taken
  assign brch_recover[0] = od0_brch_taken_mem;
  assign brch_recover[1] = od1_brch_taken_mem;
  assign pc_execute[0]   = od0_brch_pc_mem;
  assign pc_execute[1]   = od1_brch_pc_mem;
  assign brch_pc_wb[0]   = od0_pc_mem;
  assign brch_pc_wb[1]   = od1_pc_mem;
  assign br_recover      = brch_recover[0] | brch_recover[1];
  assign flush_core      = flush | br_recover;

  state_LUT u_state_lut0 (
    .state      (brch_state[0]),
    .pc_sctrl   (brch_recover[0]),
    .next_state (brch_state_wb[0])
  );

  state_LUT u_state_lut1 (
    .state      (brch_state[1]),
    .pc_sctrl   (brch_recover[1]),
    .next_state (brch_state_wb[1])
  );

  s5_memory_struct u_memory (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .od0_mem_en_mem    (od0_mem_en_mem),
    .od0_mem_write_mem (od0_mem_write_mem),
    .od1_mem_en_mem    (od1_mem_en_mem),
    .od1_mem_write_mem (od1_mem_write_mem),
    .od0_mem_addr_mem  (od0_mem_addr_mem),
    .od0_mem_wdata_mem (od0_mem_wdata_mem),
    .od0_mem_besel_mem (od0_mem_besel_mem),
    .od1_mem_addr_mem  (od1_mem_addr_mem),
    .od1_mem_wdata_mem (od1_mem_wdata_mem),
    .od1_mem_besel_mem (od1_mem_besel_mem),
    .od0_load_mem_data (od0_load_mem_data),
    .od1_load_mem_data (od1_load_mem_data),
    .dcache_busy       (dcache_busy)
  );

  ex_mem_wb u_ex_mem_wb (
    .clk                (clk),
    .rst_n              (rst_n),
    .enable             (enable),
    .flush              (flush_core),
    .ev0_reg_write_ex   (ev_enable_ex[0] && ev_reg_write_ex[0]),
    .ev0_rd_addr_ex     (ev_prd_ex[0]),
    .ev0_wdata_ex       (ev_alu_result[0]),
    .ev0_pc_ex          (ev_pc_ex[0]),
    .ev1_reg_write_ex   (ev_enable_ex[1] && ev_reg_write_ex[1]),
    .ev1_rd_addr_ex     (ev_prd_ex[1]),
    .ev1_wdata_ex       (ev_alu_result[1]),
    .ev1_pc_ex          (ev_pc_ex[1]),
    .od0_reg_write_mem  (od0_reg_write_mem),
    .od0_rd_addr_mem    (od0_rd_addr_mem),
    .od0_pc_mem         (od0_pc_mem),
    .od0_use_link_mem   (od0_use_link_mem),
    .od0_alu_result_mem (od0_alu_result_mem),
    .od0_mem_en_mem     (od0_mem_en_mem),
    .od0_mem_write_mem  (od0_mem_write_mem),
    .od0_load_mem_data  (od0_load_mem_data),
    .od1_reg_write_mem  (od1_reg_write_mem),
    .od1_rd_addr_mem    (od1_rd_addr_mem),
    .od1_pc_mem         (od1_pc_mem),
    .od1_use_link_mem   (od1_use_link_mem),
    .od1_alu_result_mem (od1_alu_result_mem),
    .od1_mem_en_mem     (od1_mem_en_mem),
    .od1_mem_write_mem  (od1_mem_write_mem),
    .od1_load_mem_data  (od1_load_mem_data),
    .ev0_reg_write_exwb (),
    .ev0_rd_addr_exwb   (),
    .ev0_wdata_exwb     (),
    .ev0_pc_exwb        (),
    .ev1_reg_write_exwb (),
    .ev1_rd_addr_exwb   (),
    .ev1_wdata_exwb     (),
    .ev1_pc_exwb        (),
    .od0_wdata_mem      (),
    .od1_wdata_mem      (),
    .push0_valid        (wb_push0_valid),
    .push0_rd_addr      (wb_push0_rd_addr),
    .push0_wdata        (wb_push0_wdata),
    .push0_pc           (),
    .push1_valid        (wb_push1_valid),
    .push1_rd_addr      (wb_push1_rd_addr),
    .push1_wdata        (wb_push1_wdata),
    .push1_pc           ()
  );

endmodule
