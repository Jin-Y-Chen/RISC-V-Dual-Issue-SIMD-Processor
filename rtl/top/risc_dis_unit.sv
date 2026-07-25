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
  logic resolve_en;
  logic resolve_mispred;
  logic wbrack;
  logic stall_rn;
  logic stall_dp;
  logic stall_ex;
  logic stall_id_rn;

  // -------------------------------------------------------------------------
  // Fetch / IF-ID
  // -------------------------------------------------------------------------
  logic        i0_pred_taken, i1_pred_taken;
  logic        i0_brch_recover, i1_brch_recover;
  logic [31:0] i0_pc_execute, i1_pc_execute;

  logic [31:0] i0_instr_if, i1_instr_if;
  logic [31:0] i0_pc_if, i1_pc_if;
  logic [31:0] i0_pc_target_if, i1_pc_target_if;
  logic        i0_valid_if, i1_valid_if;
  logic        i0_target_valid_if, i1_target_valid_if;
  logic        spec0_en_if, spec1_en_if;

  logic [31:0] i0_instr_id, i1_instr_id;
  logic [31:0] i0_pc_id, i1_pc_id;
  logic [31:0] i0_pc_target_id, i1_pc_target_id;
  logic        i0_valid_id, i1_valid_id;
  logic        i0_target_valid_id, i1_target_valid_id;
  logic        spec0_en_id, spec1_en_id;

  logic        i0_spec_stall_dec, i1_spec_stall_dec;

  logic        i0_br_valid_wb, i1_br_valid_wb;
  logic [31:0] i0_btb_pc_wb, i1_btb_pc_wb;
  logic [31:0] i0_pc_target_wb, i1_pc_target_wb;
  br_state_t   i0_target_state_wb, i1_target_state_wb;

  assign i0_pc_if = pc_fetch;
  assign i1_pc_if = pc_fetch_plus4;
  assign stall_id = stall_id_rn;

  s1_fetch_struct #(
    .RESET_PC(RESET_PC)
  ) u_fetch (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .dispatch_stall   (stall_id),
    .spec0_stall      (i0_spec_stall_dec),
    .spec1_stall      (i1_spec_stall_dec),
    .i0_pred_taken    (i0_pred_taken),
    .i1_pred_taken    (i1_pred_taken),
    .i0_brch_recover  (i0_brch_recover),
    .i1_brch_recover  (i1_brch_recover),
    .i0_pc_execute    (i0_pc_execute),
    .i1_pc_execute    (i1_pc_execute),
    .i0_valid_wb      (i0_br_valid_wb),
    .i1_valid_wb      (i1_br_valid_wb),
    .i0_pc_wb         (i0_btb_pc_wb),
    .i1_pc_wb         (i1_btb_pc_wb),
    .i0_pc_target_wb  (i0_pc_target_wb),
    .i1_pc_target_wb  (i1_pc_target_wb),
    .pc0              (pc_fetch),
    .pc1              (pc_fetch_plus4),
    .i0_pc_target     (i0_pc_target_if),
    .i1_pc_target     (i1_pc_target_if),
    .instr0           (i0_instr_if),
    .instr1           (i1_instr_if),
    .spec0_en         (spec0_en_if),
    .spec1_en         (spec1_en_if),
    .i0_valid         (i0_valid_if),
    .i1_valid         (i1_valid_if),
    .i0_target_valid  (i0_target_valid_if),
    .i1_target_valid  (i1_target_valid_if)
  );

  if_id u_if_id (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .flush               (flush_core),
    .stall               (stall_id),
    .i0_fetch_valid      (i0_valid_if),
    .i1_fetch_valid      (i1_valid_if),
    .i0_target_valid_if  (i0_target_valid_if),
    .i1_target_valid_if  (i1_target_valid_if),
    .spec0_en_if         (spec0_en_if),
    .spec1_en_if         (spec1_en_if),
    .i0_instr_if         (i0_instr_if),
    .i1_instr_if         (i1_instr_if),
    .i0_pc_if            (i0_pc_if),
    .i1_pc_if            (i1_pc_if),
    .i0_pc_target_if     (i0_pc_target_if),
    .i1_pc_target_if     (i1_pc_target_if),
    .i0_instr_id         (i0_instr_id),
    .i1_instr_id         (i1_instr_id),
    .i0_pc_id            (i0_pc_id),
    .i1_pc_id            (i1_pc_id),
    .i0_pc_target_id     (i0_pc_target_id),
    .i1_pc_target_id     (i1_pc_target_id),
    .i0_valid_id         (i0_valid_id),
    .i1_valid_id         (i1_valid_id),
    .i0_target_valid_id  (i0_target_valid_id),
    .i1_target_valid_id  (i1_target_valid_id),
    .spec0_en_id         (spec0_en_id),
    .spec1_en_id         (spec1_en_id)
  );

  // -------------------------------------------------------------------------
  // Decode
  // -------------------------------------------------------------------------
  logic        i0_valid_dec, i1_valid_dec;
  logic        i0_brch_en_dec, i1_brch_en_dec;
  logic        i0_jump_en_dec, i1_jump_en_dec;
  logic        i0_store_en_dec, i1_store_en_dec;
  logic        i0_lane_sel_dec, i1_lane_sel_dec;
  logic [6:0]  i0_opcode_dec, i1_opcode_dec;
  logic [2:0]  i0_funct3_dec, i1_funct3_dec;
  logic [6:0]  i0_funct7_dec, i1_funct7_dec;
  logic [4:0]  i0_rd_addr_dec, i1_rd_addr_dec;
  logic [4:0]  i0_rs1_addr_dec, i1_rs1_addr_dec;
  logic [4:0]  i0_rs2_addr_dec, i1_rs2_addr_dec;
  logic [31:0] i0_imm_dec, i1_imm_dec;
  logic        i0_rs1_use_dec, i1_rs1_use_dec;
  logic        i0_rs2_use_dec, i1_rs2_use_dec;
  logic        i0_reg_write_dec, i1_reg_write_dec;
  word_t       i0_pc_predict_dec, i1_pc_predict_dec;
  logic        i0_tp_wb_valid_dec, i1_tp_wb_valid_dec;
  br_state_t   i0_target_state, i1_target_state;

  s2_decode_struct u_decode (
    .clk                (clk),
    .rst_n              (rst_n),
    .i0_valid_id        (i0_valid_id),
    .i1_valid_id        (i1_valid_id),
    .spec0_en_id        (spec0_en_id),
    .spec1_en_id        (spec1_en_id),
    .i0_instr_id        (i0_instr_id),
    .i1_instr_id        (i1_instr_id),
    .i0_pc_id           (i0_pc_id),
    .i1_pc_id           (i1_pc_id),
    .i0_pc_target_id    (i0_pc_target_id),
    .i1_pc_target_id    (i1_pc_target_id),
    .i0_target_valid_id (i0_target_valid_id),
    .i1_target_valid_id (i1_target_valid_id),
    .i0_brch_valid_wb   (i0_br_valid_wb),
    .i1_brch_valid_wb   (i1_br_valid_wb),
    .i0_brch_pc_wb      (i0_btb_pc_wb),
    .i1_brch_pc_wb      (i1_btb_pc_wb),
    .i0_brch_state_wb   (i0_target_state_wb),
    .i1_brch_state_wb   (i1_target_state_wb),
    .i0_lane_sel        (i0_lane_sel_dec),
    .i0_opcode          (i0_opcode_dec),
    .i0_funct3          (i0_funct3_dec),
    .i0_funct7          (i0_funct7_dec),
    .i0_rd_addr         (i0_rd_addr_dec),
    .i0_rs1_addr        (i0_rs1_addr_dec),
    .i0_rs2_addr        (i0_rs2_addr_dec),
    .i0_imm             (i0_imm_dec),
    .i1_lane_sel        (i1_lane_sel_dec),
    .i1_opcode          (i1_opcode_dec),
    .i1_funct3          (i1_funct3_dec),
    .i1_funct7          (i1_funct7_dec),
    .i1_rd_addr         (i1_rd_addr_dec),
    .i1_rs1_addr        (i1_rs1_addr_dec),
    .i1_rs2_addr        (i1_rs2_addr_dec),
    .i1_imm             (i1_imm_dec),
    .i0_valid           (i0_valid_dec),
    .i0_brch_en         (i0_brch_en_dec),
    .i0_jump_en         (i0_jump_en_dec),
    .i0_store_en        (i0_store_en_dec),
    .i0_rs1_use         (i0_rs1_use_dec),
    .i0_rs2_use         (i0_rs2_use_dec),
    .i0_reg_write       (i0_reg_write_dec),
    .i1_valid           (i1_valid_dec),
    .i1_brch_en         (i1_brch_en_dec),
    .i1_jump_en         (i1_jump_en_dec),
    .i1_store_en        (i1_store_en_dec),
    .i1_rs1_use         (i1_rs1_use_dec),
    .i1_rs2_use         (i1_rs2_use_dec),
    .i1_reg_write       (i1_reg_write_dec),
    .i0_brch_state      (i0_target_state),
    .i1_brch_state      (i1_target_state),
    .i0_pc_predict      (i0_pc_predict_dec),
    .i1_pc_predict      (i1_pc_predict_dec),
    .i0_pred_taken      (i0_pred_taken),
    .i1_pred_taken      (i1_pred_taken),
    .i0_pred_valid_wb   (i0_tp_wb_valid_dec),
    .i1_pred_valid_wb   (i1_tp_wb_valid_dec),
    .i0_nest_spec_stall (i0_spec_stall_dec),
    .i1_nest_spec_stall (i1_spec_stall_dec)
  );

  // -------------------------------------------------------------------------
  // ID/RN → Rename → RN/DP → Issue
  // -------------------------------------------------------------------------
  logic        i0_valid_rn, i1_valid_rn;
  logic        i0_lane_sel_rn, i1_lane_sel_rn;
  logic        i0_reg_write_rn, i1_reg_write_rn;
  logic        i0_store_en_rn, i1_store_en_rn;
  logic        i0_rs1_use_rn, i0_rs2_use_rn;
  logic        i1_rs1_use_rn, i1_rs2_use_rn;
  br_state_t   i0_brch_state_rn, i1_brch_state_rn;
  logic        spec0_en_rn, spec1_en_rn;
  opcode_t     i0_opcode_rn, i1_opcode_rn;
  funct3_t     i0_funct3_rn, i1_funct3_rn;
  funct7_t     i0_funct7_rn, i1_funct7_rn;
  gpr_addr_t   i0_rd_addr_rn, i1_rd_addr_rn;
  gpr_addr_t   i0_rs1_addr_rn, i1_rs1_addr_rn;
  gpr_addr_t   i0_rs2_addr_rn, i1_rs2_addr_rn;
  word_t       i0_imm_rn, i1_imm_rn, i0_pc_rn, i1_pc_rn;

  logic        i0_valid_disp, i1_valid_disp;
  logic        i0_lane_sel_disp, i1_lane_sel_disp;
  logic        i0_reg_write_disp, i1_reg_write_disp;
  logic        i0_spec_en_disp, i1_spec_en_disp;
  logic        i0_rs1_use_disp, i0_rs2_use_disp;
  logic        i1_rs1_use_disp, i1_rs2_use_disp;
  opcode_t     i0_opcode_disp, i1_opcode_disp;
  funct3_t     i0_funct3_disp, i1_funct3_disp;
  funct7_t     i0_funct7_disp, i1_funct7_disp;
  gpr_addr_t   i0_rd_addr_disp, i1_rd_addr_disp;
  prf_addr_t   i0_ps1_disp, i0_ps2_disp, i0_prd_disp;
  prf_addr_t   i1_ps1_disp, i1_ps2_disp, i1_prd_disp;
  prf_addr_t   i0_rob_idx_disp, i1_rob_idx_disp;
  word_t       i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp;

  logic        retire0_en, retire1_en;
  logic        rrat0_en, rrat1_en;
  gpr_addr_t   i0_rd_addr_cmt, i1_rd_addr_cmt;
  prf_addr_t   i0_rob_idx_cmt, i1_rob_idx_cmt;
  logic        stb0_en, stb1_en;

  logic        i0_valid_dp, i1_valid_dp;
  logic        i0_lane_sel_dp, i1_lane_sel_dp;
  logic        i0_reg_write_dp, i1_reg_write_dp;
  logic        i0_spec_en_dp, i1_spec_en_dp;
  logic        i0_rs1_use_dp, i0_rs2_use_dp;
  logic        i1_rs1_use_dp, i1_rs2_use_dp;
  opcode_t     i0_opcode_dp, i1_opcode_dp;
  funct3_t     i0_funct3_dp, i1_funct3_dp;
  funct7_t     i0_funct7_dp, i1_funct7_dp;
  gpr_addr_t   i0_rd_addr_dp, i1_rd_addr_dp;
  prf_addr_t   i0_ps1_dp, i0_ps2_dp, i0_prd_dp;
  prf_addr_t   i1_ps1_dp, i1_ps2_dp, i1_prd_dp;
  prf_addr_t   i0_rob_idx_dp, i1_rob_idx_dp;
  word_t       i0_imm_dp, i1_imm_dp, i0_pc_dp, i1_pc_dp;

  logic        wb0_en, wb1_en;
  prf_addr_t   wb0_prd, wb1_prd;
  word_t       wb0_data, wb1_data;
  logic        wback0_en, wback1_en;
  prf_addr_t   i0_rob_idx_wb, i1_rob_idx_wb;
  logic        i0_brch_taken_wb, i1_brch_taken_wb;

  logic        ev0_enable_ex, ev1_enable_ex, od0_enable_ex, od1_enable_ex;
  logic        ev0_reg_write_ex, ev1_reg_write_ex;
  logic        od0_reg_write_ex, od1_reg_write_ex;
  opcode_t     ev0_opcode_ex, ev1_opcode_ex, od0_opcode_ex, od1_opcode_ex;
  funct3_t     ev0_funct3_ex, ev1_funct3_ex, od0_funct3_ex, od1_funct3_ex;
  funct7_t     ev0_funct7_ex, ev1_funct7_ex;
  prf_addr_t   ev0_prd_ex, ev1_prd_ex, od0_prd_ex, od1_prd_ex;
  word_t       ev0_imm_ex, ev1_imm_ex, od0_imm_ex, od1_imm_ex;
  word_t       ev0_pc_ex, ev1_pc_ex, od0_pc_ex, od1_pc_ex;
  word_t       ev0_rs1_data_ex, ev0_rs2_data_ex;
  word_t       ev1_rs1_data_ex, ev1_rs2_data_ex;
  word_t       od0_rs1_data_ex, od0_rs2_data_ex;
  word_t       od1_rs1_data_ex, od1_rs2_data_ex;

  id_rn u_id_rn (
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    .flush            (flush_core),
    .stall            (stall_id),
    .i0_valid_id      (i0_valid_dec),
    .i0_lane_sel_id   (i0_lane_sel_dec),
    .i0_reg_write_id  (i0_reg_write_dec),
    .i0_store_en_id   (i0_store_en_dec),
    .i0_rs1_use_id    (i0_rs1_use_dec),
    .i0_rs2_use_id    (i0_rs2_use_dec),
    .i0_brch_state_id (i0_target_state),
    .spec0_en_id      (spec0_en_id),
    .i1_valid_id      (i1_valid_dec),
    .i1_lane_sel_id   (i1_lane_sel_dec),
    .i1_reg_write_id  (i1_reg_write_dec),
    .i1_store_en_id   (i1_store_en_dec),
    .i1_rs1_use_id    (i1_rs1_use_dec),
    .i1_rs2_use_id    (i1_rs2_use_dec),
    .i1_brch_state_id (i1_target_state),
    .spec1_en_id      (spec1_en_id),
    .i0_opcode_id     (i0_opcode_dec),
    .i0_funct3_id     (i0_funct3_dec),
    .i0_funct7_id     (i0_funct7_dec),
    .i0_rd_addr_id    (i0_rd_addr_dec),
    .i0_rs1_addr_id   (i0_rs1_addr_dec),
    .i0_rs2_addr_id   (i0_rs2_addr_dec),
    .i0_imm_id        (i0_imm_dec),
    .i0_pc_id         (i0_pc_id),
    .i1_opcode_id     (i1_opcode_dec),
    .i1_funct3_id     (i1_funct3_dec),
    .i1_funct7_id     (i1_funct7_dec),
    .i1_rd_addr_id    (i1_rd_addr_dec),
    .i1_rs1_addr_id   (i1_rs1_addr_dec),
    .i1_rs2_addr_id   (i1_rs2_addr_dec),
    .i1_imm_id        (i1_imm_dec),
    .i1_pc_id         (i1_pc_id),
    .i0_valid_rn      (i0_valid_rn),
    .i0_lane_sel_rn   (i0_lane_sel_rn),
    .i0_reg_write_rn  (i0_reg_write_rn),
    .i0_store_en_rn   (i0_store_en_rn),
    .i0_rs1_use_rn    (i0_rs1_use_rn),
    .i0_rs2_use_rn    (i0_rs2_use_rn),
    .i0_brch_state_rn (i0_brch_state_rn),
    .spec0_en_rn      (spec0_en_rn),
    .i1_valid_rn      (i1_valid_rn),
    .i1_lane_sel_rn   (i1_lane_sel_rn),
    .i1_reg_write_rn  (i1_reg_write_rn),
    .i1_store_en_rn   (i1_store_en_rn),
    .i1_rs1_use_rn    (i1_rs1_use_rn),
    .i1_rs2_use_rn    (i1_rs2_use_rn),
    .i1_brch_state_rn (i1_brch_state_rn),
    .spec1_en_rn      (spec1_en_rn),
    .i0_opcode_rn     (i0_opcode_rn),
    .i0_funct3_rn     (i0_funct3_rn),
    .i0_funct7_rn     (i0_funct7_rn),
    .i0_rd_addr_rn    (i0_rd_addr_rn),
    .i0_rs1_addr_rn   (i0_rs1_addr_rn),
    .i0_rs2_addr_rn   (i0_rs2_addr_rn),
    .i0_imm_rn        (i0_imm_rn),
    .i0_pc_rn         (i0_pc_rn),
    .i1_opcode_rn     (i1_opcode_rn),
    .i1_funct3_rn     (i1_funct3_rn),
    .i1_funct7_rn     (i1_funct7_rn),
    .i1_rd_addr_rn    (i1_rd_addr_rn),
    .i1_rs1_addr_rn   (i1_rs1_addr_rn),
    .i1_rs2_addr_rn   (i1_rs2_addr_rn),
    .i1_imm_rn        (i1_imm_rn),
    .i1_pc_rn         (i1_pc_rn)
  );

  rename_core_struct u_rename (
    .clk               (clk),
    .rst_n             (rst_n),
    .flush             (flush_core),
    .stall_rn          (stall_rn),
    .enable            (enable),
    .spec0_en_rn       (spec0_en_rn),
    .spec1_en_rn       (spec1_en_rn),
    .i0_valid_rn       (i0_valid_rn),
    .i1_valid_rn       (i1_valid_rn),
    .i0_lane_sel_rn    (i0_lane_sel_rn),
    .i1_lane_sel_rn    (i1_lane_sel_rn),
    .i0_reg_write_rn   (i0_reg_write_rn),
    .i1_reg_write_rn   (i1_reg_write_rn),
    .i0_store_en_rn    (i0_store_en_rn),
    .i1_store_en_rn    (i1_store_en_rn),
    .i0_rs1_use_rn     (i0_rs1_use_rn),
    .i0_rs2_use_rn     (i0_rs2_use_rn),
    .i1_rs1_use_rn     (i1_rs1_use_rn),
    .i1_rs2_use_rn     (i1_rs2_use_rn),
    .i0_opcode_rn      (i0_opcode_rn),
    .i1_opcode_rn      (i1_opcode_rn),
    .i0_funct3_rn      (i0_funct3_rn),
    .i1_funct3_rn      (i1_funct3_rn),
    .i0_funct7_rn      (i0_funct7_rn),
    .i1_funct7_rn      (i1_funct7_rn),
    .i0_rd_addr_rn     (i0_rd_addr_rn),
    .i0_rs1_addr_rn    (i0_rs1_addr_rn),
    .i0_rs2_addr_rn    (i0_rs2_addr_rn),
    .i1_rd_addr_rn     (i1_rd_addr_rn),
    .i1_rs1_addr_rn    (i1_rs1_addr_rn),
    .i1_rs2_addr_rn    (i1_rs2_addr_rn),
    .i0_imm_rn         (i0_imm_rn),
    .i0_pc_rn          (i0_pc_rn),
    .i1_imm_rn         (i1_imm_rn),
    .i1_pc_rn          (i1_pc_rn),
    .wback0_en         (wback0_en),
    .wback1_en         (wback1_en),
    .i0_rob_idx_wb     (i0_rob_idx_wb),
    .i1_rob_idx_wb     (i1_rob_idx_wb),
    .i0_brch_taken_wb  (i0_brch_taken_wb),
    .i1_brch_taken_wb  (i1_brch_taken_wb),
    .resolve_en        (resolve_en),
    .resolve_mispred   (resolve_mispred),
    .stall_id          (stall_id_rn),
    .i0_valid_disp     (i0_valid_disp),
    .i1_valid_disp     (i1_valid_disp),
    .i0_lane_sel_disp  (i0_lane_sel_disp),
    .i1_lane_sel_disp  (i1_lane_sel_disp),
    .i0_reg_write_disp (i0_reg_write_disp),
    .i1_reg_write_disp (i1_reg_write_disp),
    .i0_spec_en_disp   (i0_spec_en_disp),
    .i1_spec_en_disp   (i1_spec_en_disp),
    .i0_rs1_use_disp   (i0_rs1_use_disp),
    .i0_rs2_use_disp   (i0_rs2_use_disp),
    .i1_rs1_use_disp   (i1_rs1_use_disp),
    .i1_rs2_use_disp   (i1_rs2_use_disp),
    .i0_opcode_disp    (i0_opcode_disp),
    .i1_opcode_disp    (i1_opcode_disp),
    .i0_funct3_disp    (i0_funct3_disp),
    .i1_funct3_disp    (i1_funct3_disp),
    .i0_funct7_disp    (i0_funct7_disp),
    .i1_funct7_disp    (i1_funct7_disp),
    .i0_rd_addr_disp   (i0_rd_addr_disp),
    .i1_rd_addr_disp   (i1_rd_addr_disp),
    .i0_ps1_disp       (i0_ps1_disp),
    .i0_ps2_disp       (i0_ps2_disp),
    .i0_prd_disp       (i0_prd_disp),
    .i1_ps1_disp       (i1_ps1_disp),
    .i1_ps2_disp       (i1_ps2_disp),
    .i1_prd_disp       (i1_prd_disp),
    .i0_rob_idx_disp   (i0_rob_idx_disp),
    .i1_rob_idx_disp   (i1_rob_idx_disp),
    .i0_imm_disp       (i0_imm_disp),
    .i1_imm_disp       (i1_imm_disp),
    .i0_pc_disp        (i0_pc_disp),
    .i1_pc_disp        (i1_pc_disp),
    .retire0_en        (retire0_en),
    .retire1_en        (retire1_en),
    .rrat0_en          (rrat0_en),
    .rrat1_en          (rrat1_en),
    .i0_rd_addr_cmt    (i0_rd_addr_cmt),
    .i1_rd_addr_cmt    (i1_rd_addr_cmt),
    .i0_rob_idx_cmt    (i0_rob_idx_cmt),
    .i1_rob_idx_cmt    (i1_rob_idx_cmt),
    .stb0_en           (stb0_en),
    .stb1_en           (stb1_en)
  );

  rn_dp u_rn_dp (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .flush           (flush_core),
    .stall_dp        (stall_dp),
    .stall_rn        (stall_rn),
    .i0_valid_rn     (i0_valid_disp),
    .i0_lane_sel_rn  (i0_lane_sel_disp),
    .i0_reg_write_rn (i0_reg_write_disp),
    .i0_spec_en_rn   (i0_spec_en_disp),
    .i0_rs1_use_rn   (i0_rs1_use_disp),
    .i0_rs2_use_rn   (i0_rs2_use_disp),
    .i0_opcode_rn    (i0_opcode_disp),
    .i0_funct3_rn    (i0_funct3_disp),
    .i0_funct7_rn    (i0_funct7_disp),
    .i0_rd_addr_rn   (i0_rd_addr_disp),
    .i0_ps1_rn       (i0_ps1_disp),
    .i0_ps2_rn       (i0_ps2_disp),
    .i0_prd_rn       (i0_prd_disp),
    .i0_rob_idx_rn   (i0_rob_idx_disp),
    .i0_imm_rn       (i0_imm_disp),
    .i0_pc_rn        (i0_pc_disp),
    .i1_valid_rn     (i1_valid_disp),
    .i1_lane_sel_rn  (i1_lane_sel_disp),
    .i1_reg_write_rn (i1_reg_write_disp),
    .i1_spec_en_rn   (i1_spec_en_disp),
    .i1_rs1_use_rn   (i1_rs1_use_disp),
    .i1_rs2_use_rn   (i1_rs2_use_disp),
    .i1_opcode_rn    (i1_opcode_disp),
    .i1_funct3_rn    (i1_funct3_disp),
    .i1_funct7_rn    (i1_funct7_disp),
    .i1_rd_addr_rn   (i1_rd_addr_disp),
    .i1_ps1_rn       (i1_ps1_disp),
    .i1_ps2_rn       (i1_ps2_disp),
    .i1_prd_rn       (i1_prd_disp),
    .i1_rob_idx_rn   (i1_rob_idx_disp),
    .i1_imm_rn       (i1_imm_disp),
    .i1_pc_rn        (i1_pc_disp),
    .i0_valid_dp     (i0_valid_dp),
    .i0_lane_sel_dp  (i0_lane_sel_dp),
    .i0_reg_write_dp (i0_reg_write_dp),
    .i0_spec_en_dp   (i0_spec_en_dp),
    .i0_rs1_use_dp   (i0_rs1_use_dp),
    .i0_rs2_use_dp   (i0_rs2_use_dp),
    .i0_opcode_dp    (i0_opcode_dp),
    .i0_funct3_dp    (i0_funct3_dp),
    .i0_funct7_dp    (i0_funct7_dp),
    .i0_rd_addr_dp   (i0_rd_addr_dp),
    .i0_ps1_dp       (i0_ps1_dp),
    .i0_ps2_dp       (i0_ps2_dp),
    .i0_prd_dp       (i0_prd_dp),
    .i0_rob_idx_dp   (i0_rob_idx_dp),
    .i0_imm_dp       (i0_imm_dp),
    .i0_pc_dp        (i0_pc_dp),
    .i1_valid_dp     (i1_valid_dp),
    .i1_lane_sel_dp  (i1_lane_sel_dp),
    .i1_reg_write_dp (i1_reg_write_dp),
    .i1_spec_en_dp   (i1_spec_en_dp),
    .i1_rs1_use_dp   (i1_rs1_use_dp),
    .i1_rs2_use_dp   (i1_rs2_use_dp),
    .i1_opcode_dp    (i1_opcode_dp),
    .i1_funct3_dp    (i1_funct3_dp),
    .i1_funct7_dp    (i1_funct7_dp),
    .i1_rd_addr_dp   (i1_rd_addr_dp),
    .i1_ps1_dp       (i1_ps1_dp),
    .i1_ps2_dp       (i1_ps2_dp),
    .i1_prd_dp       (i1_prd_dp),
    .i1_rob_idx_dp   (i1_rob_idx_dp),
    .i1_imm_dp       (i1_imm_dp),
    .i1_pc_dp        (i1_pc_dp)
  );

  issue_core_struct u_issue (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .flush             (flush_core),
    .stall_ex          (stall_ex),
    .i0_valid_dp       (i0_valid_dp),
    .i0_lane_sel_dp    (i0_lane_sel_dp),
    .i0_reg_write_dp   (i0_reg_write_dp),
    .i0_spec_en_dp     (i0_spec_en_dp),
    .i0_opcode_dp      (i0_opcode_dp),
    .i0_funct3_dp      (i0_funct3_dp),
    .i0_funct7_dp      (i0_funct7_dp),
    .i0_ps1_dp         (i0_ps1_dp),
    .i0_ps2_dp         (i0_ps2_dp),
    .i0_prd_dp         (i0_prd_dp),
    .i0_imm_dp         (i0_imm_dp),
    .i0_pc_dp          (i0_pc_dp),
    .i1_valid_dp       (i1_valid_dp),
    .i1_lane_sel_dp    (i1_lane_sel_dp),
    .i1_reg_write_dp   (i1_reg_write_dp),
    .i1_spec_en_dp     (i1_spec_en_dp),
    .i1_opcode_dp      (i1_opcode_dp),
    .i1_funct3_dp      (i1_funct3_dp),
    .i1_funct7_dp      (i1_funct7_dp),
    .i1_ps1_dp         (i1_ps1_dp),
    .i1_ps2_dp         (i1_ps2_dp),
    .i1_prd_dp         (i1_prd_dp),
    .i1_imm_dp         (i1_imm_dp),
    .i1_pc_dp          (i1_pc_dp),
    .wb0_en            (wb0_en),
    .wb0_prd           (wb0_prd),
    .wb0_data          (wb0_data),
    .wb1_en            (wb1_en),
    .wb1_prd           (wb1_prd),
    .wb1_data          (wb1_data),
    .wbrack            (wbrack),
    .stall_dp          (stall_dp),
    .ev0_enable_ex     (ev0_enable_ex),
    .ev0_reg_write_ex  (ev0_reg_write_ex),
    .ev0_opcode_ex     (ev0_opcode_ex),
    .ev0_funct3_ex     (ev0_funct3_ex),
    .ev0_funct7_ex     (ev0_funct7_ex),
    .ev0_prd_ex        (ev0_prd_ex),
    .ev0_imm_ex        (ev0_imm_ex),
    .ev0_pc_ex         (ev0_pc_ex),
    .ev0_rs1_data_ex   (ev0_rs1_data_ex),
    .ev0_rs2_data_ex   (ev0_rs2_data_ex),
    .ev1_enable_ex     (ev1_enable_ex),
    .ev1_reg_write_ex  (ev1_reg_write_ex),
    .ev1_opcode_ex     (ev1_opcode_ex),
    .ev1_funct3_ex     (ev1_funct3_ex),
    .ev1_funct7_ex     (ev1_funct7_ex),
    .ev1_prd_ex        (ev1_prd_ex),
    .ev1_imm_ex        (ev1_imm_ex),
    .ev1_pc_ex         (ev1_pc_ex),
    .ev1_rs1_data_ex   (ev1_rs1_data_ex),
    .ev1_rs2_data_ex   (ev1_rs2_data_ex),
    .od0_enable_ex     (od0_enable_ex),
    .od0_reg_write_ex  (od0_reg_write_ex),
    .od0_opcode_ex     (od0_opcode_ex),
    .od0_funct3_ex     (od0_funct3_ex),
    .od0_prd_ex        (od0_prd_ex),
    .od0_imm_ex        (od0_imm_ex),
    .od0_pc_ex         (od0_pc_ex),
    .od0_rs1_data_ex   (od0_rs1_data_ex),
    .od0_rs2_data_ex   (od0_rs2_data_ex),
    .od1_enable_ex     (od1_enable_ex),
    .od1_reg_write_ex  (od1_reg_write_ex),
    .od1_opcode_ex     (od1_opcode_ex),
    .od1_funct3_ex     (od1_funct3_ex),
    .od1_prd_ex        (od1_prd_ex),
    .od1_imm_ex        (od1_imm_ex),
    .od1_pc_ex         (od1_pc_ex),
    .od1_rs1_data_ex   (od1_rs1_data_ex),
    .od1_rs2_data_ex   (od1_rs2_data_ex)
  );

  // -------------------------------------------------------------------------
  // Execute → MEM → WB
  // -------------------------------------------------------------------------
  logic [31:0] ev0_alu_result, ev1_alu_result;
  logic        od0_use_link_ex, od1_use_link_ex;
  logic        od0_brch_taken, od1_brch_taken;
  logic [31:0] od0_brch_pc, od1_brch_pc;
  logic        od0_mem_en, od1_mem_en;
  logic        od0_mem_write, od1_mem_write;
  logic [31:0] od0_mem_addr, od1_mem_addr;
  logic [31:0] od0_mem_wdata, od1_mem_wdata;
  logic [3:0]  od0_mem_besel, od1_mem_besel;
  logic [31:0] od0_link_pc, od1_link_pc;
  logic [31:0] od0_alu_result, od1_alu_result;

  logic        od0_use_link_mem, od1_use_link_mem;
  logic        od0_reg_write_mem, od1_reg_write_mem;
  prf_addr_t   od0_rd_addr_mem, od1_rd_addr_mem;
  logic        od0_brch_taken_mem, od1_brch_taken_mem;
  logic [31:0] od0_brch_pc_mem, od1_brch_pc_mem;
  logic        od0_mem_en_mem, od1_mem_en_mem;
  logic        od0_mem_write_mem, od1_mem_write_mem;
  logic [31:0] od0_mem_addr_mem, od1_mem_addr_mem;
  logic [31:0] od0_mem_wdata_mem, od1_mem_wdata_mem;
  logic [3:0]  od0_mem_besel_mem, od1_mem_besel_mem;
  logic [31:0] od0_link_pc_mem, od1_link_pc_mem;
  logic [31:0] od0_alu_result_mem, od1_alu_result_mem;
  logic [31:0] od0_pc_mem, od1_pc_mem;
  logic [31:0] od0_load_mem_data, od1_load_mem_data;
  logic        dcache_busy;

  logic        wb_push0_valid, wb_push1_valid;
  prf_addr_t   wb_push0_rd_addr, wb_push1_rd_addr;
  logic [31:0] wb_push0_wdata, wb_push1_wdata;
  logic [31:0] wb_push0_pc, wb_push1_pc;

  assign stall_ex = dcache_busy;

  s4_execute_struct u_execute (
    .ev0_enable_ex   (ev0_enable_ex),
    .ev0_opcode_ex   (ev0_opcode_ex),
    .ev0_funct3_ex   (ev0_funct3_ex),
    .ev0_funct7_ex   (ev0_funct7_ex),
    .ev0_imm_ex      (ev0_imm_ex),
    .ev0_rs1_data_ex (ev0_rs1_data_ex),
    .ev0_rs2_data_ex (ev0_rs2_data_ex),
    .ev1_enable_ex   (ev1_enable_ex),
    .ev1_opcode_ex   (ev1_opcode_ex),
    .ev1_funct3_ex   (ev1_funct3_ex),
    .ev1_funct7_ex   (ev1_funct7_ex),
    .ev1_imm_ex      (ev1_imm_ex),
    .ev1_rs1_data_ex (ev1_rs1_data_ex),
    .ev1_rs2_data_ex (ev1_rs2_data_ex),
    .od0_enable_ex   (od0_enable_ex),
    .od0_opcode_ex   (od0_opcode_ex),
    .od0_funct3_ex   (od0_funct3_ex),
    .od0_imm_ex      (od0_imm_ex),
    .od0_pc_ex       (od0_pc_ex),
    .od0_rs1_data_ex (od0_rs1_data_ex),
    .od0_rs2_data_ex (od0_rs2_data_ex),
    .od1_enable_ex   (od1_enable_ex),
    .od1_opcode_ex   (od1_opcode_ex),
    .od1_funct3_ex   (od1_funct3_ex),
    .od1_imm_ex      (od1_imm_ex),
    .od1_pc_ex       (od1_pc_ex),
    .od1_rs1_data_ex (od1_rs1_data_ex),
    .od1_rs2_data_ex (od1_rs2_data_ex),
    .od0_use_link_ex (od0_use_link_ex),
    .od1_use_link_ex (od1_use_link_ex),
    .od0_brch_taken  (od0_brch_taken),
    .od0_mem_en      (od0_mem_en),
    .od0_mem_write   (od0_mem_write),
    .od1_brch_taken  (od1_brch_taken),
    .od1_mem_en      (od1_mem_en),
    .od1_mem_write   (od1_mem_write),
    .ev0_alu_result  (ev0_alu_result),
    .ev1_alu_result  (ev1_alu_result),
    .od0_brch_pc     (od0_brch_pc),
    .od0_mem_addr    (od0_mem_addr),
    .od0_mem_wdata   (od0_mem_wdata),
    .od0_mem_besel   (od0_mem_besel),
    .od0_link_pc     (od0_link_pc),
    .od0_alu_result  (od0_alu_result),
    .od1_brch_pc     (od1_brch_pc),
    .od1_mem_addr    (od1_mem_addr),
    .od1_mem_wdata   (od1_mem_wdata),
    .od1_mem_besel   (od1_mem_besel),
    .od1_link_pc     (od1_link_pc),
    .od1_alu_result  (od1_alu_result)
  );

  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .stall_od0           (dcache_busy && od0_mem_en_mem),
    .stall_od1           (dcache_busy && od1_mem_en_mem),
    .od0_enable_ex       (od0_enable_ex),
    .od0_reg_write_ex    (od0_reg_write_ex),
    .od0_rd_addr_ex      (od0_prd_ex),
    .od0_brch_taken_ex   (od0_brch_taken),
    .od0_brch_pc_ex      (od0_brch_pc),
    .od0_mem_en_ex       (od0_mem_en),
    .od0_mem_write_ex    (od0_mem_write),
    .od0_mem_addr_ex     (od0_mem_addr),
    .od0_mem_wdata_ex    (od0_mem_wdata),
    .od0_mem_besel_ex    (od0_mem_besel),
    .od0_link_pc_ex      (od0_link_pc),
    .od0_alu_result_ex   (od0_alu_result),
    .od0_use_link_ex     (od0_use_link_ex),
    .od0_pc_ex           (od0_pc_ex),
    .od1_enable_ex       (od1_enable_ex),
    .od1_reg_write_ex    (od1_reg_write_ex),
    .od1_rd_addr_ex      (od1_prd_ex),
    .od1_brch_taken_ex   (od1_brch_taken),
    .od1_brch_pc_ex      (od1_brch_pc),
    .od1_mem_en_ex       (od1_mem_en),
    .od1_mem_write_ex    (od1_mem_write),
    .od1_mem_addr_ex     (od1_mem_addr),
    .od1_mem_wdata_ex    (od1_mem_wdata),
    .od1_mem_besel_ex    (od1_mem_besel),
    .od1_link_pc_ex      (od1_link_pc),
    .od1_alu_result_ex   (od1_alu_result),
    .od1_use_link_ex     (od1_use_link_ex),
    .od1_pc_ex           (od1_pc_ex),
    .od0_reg_write_mem   (od0_reg_write_mem),
    .od0_rd_addr_mem     (od0_rd_addr_mem),
    .od0_brch_taken_mem  (od0_brch_taken_mem),
    .od0_brch_pc_mem     (od0_brch_pc_mem),
    .od0_mem_en_mem      (od0_mem_en_mem),
    .od0_mem_write_mem   (od0_mem_write_mem),
    .od0_mem_addr_mem    (od0_mem_addr_mem),
    .od0_mem_wdata_mem   (od0_mem_wdata_mem),
    .od0_mem_besel_mem   (od0_mem_besel_mem),
    .od0_link_pc_mem     (od0_link_pc_mem),
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
    .od1_link_pc_mem     (od1_link_pc_mem),
    .od1_alu_result_mem  (od1_alu_result_mem),
    .od1_use_link_mem    (od1_use_link_mem),
    .od1_pc_mem          (od1_pc_mem)
  );

  assign i0_brch_recover   = od0_brch_taken_mem;
  assign i1_brch_recover   = od1_brch_taken_mem;
  assign i0_pc_execute     = od0_brch_pc_mem;
  assign i1_pc_execute     = od1_brch_pc_mem;
  assign br_recover        = i0_brch_recover | i1_brch_recover;
  assign flush_core        = flush | br_recover;
  assign resolve_en        = br_recover;
  assign resolve_mispred   = br_recover;
  assign wbrack            = br_recover;

  assign i0_br_valid_wb    = od0_brch_taken_mem;
  assign i1_br_valid_wb    = od1_brch_taken_mem;
  assign i0_btb_pc_wb      = od0_pc_mem;
  assign i1_btb_pc_wb      = od1_pc_mem;
  assign i0_pc_target_wb   = od0_brch_pc_mem;
  assign i1_pc_target_wb   = od1_brch_pc_mem;

  state_LUT u_state_lut0 (
    .state      (i0_target_state),
    .pc_sctrl   (od0_brch_taken_mem),
    .next_state (i0_target_state_wb)
  );

  state_LUT u_state_lut1 (
    .state      (i1_target_state),
    .pc_sctrl   (od1_brch_taken_mem),
    .next_state (i1_target_state_wb)
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
    .ev0_reg_write_ex   (ev0_enable_ex && ev0_reg_write_ex),
    .ev0_rd_addr_ex     (ev0_prd_ex),
    .ev0_wdata_ex       (ev0_alu_result),
    .ev0_pc_ex          (ev0_pc_ex),
    .ev1_reg_write_ex   (ev1_enable_ex && ev1_reg_write_ex),
    .ev1_rd_addr_ex     (ev1_prd_ex),
    .ev1_wdata_ex       (ev1_alu_result),
    .ev1_pc_ex          (ev1_pc_ex),
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
    .push0_pc           (wb_push0_pc),
    .push1_valid        (wb_push1_valid),
    .push1_rd_addr      (wb_push1_rd_addr),
    .push1_wdata        (wb_push1_wdata),
    .push1_pc           (wb_push1_pc)
  );

  // Complete → PRF wakeup + ROB mark-done
  assign wb0_en           = wb_push0_valid;
  assign wb0_prd          = wb_push0_rd_addr;
  assign wb0_data         = wb_push0_wdata;
  assign wb1_en           = wb_push1_valid;
  assign wb1_prd          = wb_push1_rd_addr;
  assign wb1_data         = wb_push1_wdata;

  assign wback0_en        = wb_push0_valid;
  assign wback1_en        = wb_push1_valid;
  assign i0_rob_idx_wb    = wb_push0_rd_addr;
  assign i1_rob_idx_wb    = wb_push1_rd_addr;
  assign i0_brch_taken_wb = od0_brch_taken_mem;
  assign i1_brch_taken_wb = od1_brch_taken_mem;

endmodule
