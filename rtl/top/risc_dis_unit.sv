`timescale 1ns / 1ps

// RV-DIS scalar core: fetch → decode → dispatch → execute → memory → writeback.
import rv_dis_pkg::*;

module risc_dis_unit #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        flush,

  // output data
  output word_t         pc_fetch,
  output word_t         pc_fetch_plus4,
  output logic        stall_id
);

  logic        flush_core;
  logic        br_recover;

  // Writeback → GPR (decode) and BTB / predictor (fetch)
  logic        i0_reg_write_wb;
  logic [4:0]  i0_rd_addr_wb;
  logic [31:0] i0_wdata_wb;
  logic [31:0] i0_gpr_wpc;
  logic        i1_reg_write_wb;
  logic [4:0]  i1_rd_addr_wb;
  logic [31:0] i1_wdata_wb;
  logic [31:0] i1_gpr_wpc;

  logic        i0_br_valid_wb;
  logic        i1_br_valid_wb;
  logic [31:0] i0_btb_pc_wb;
  logic [31:0] i1_btb_pc_wb;
  logic [31:0] i0_pc_target_wb;
  logic [31:0] i1_pc_target_wb;

  // -------------------------------------------------------------------------
  // Fetch — PC + instruction cache (dual-issue pair)
  // -------------------------------------------------------------------------
  logic        i0_pred_taken;
  logic        i1_pred_taken;
  logic        i0_brch_recover;
  logic        i1_brch_recover;
  logic [31:0] i0_pc_execute;
  logic [31:0] i1_pc_execute;

  logic [31:0] i0_instr_if;
  logic [31:0] i1_instr_if;
  logic [31:0] i0_pc_if;
  logic [31:0] i1_pc_if;
  logic [31:0] i0_pc_target_if;
  logic [31:0] i1_pc_target_if;
  logic        i0_valid_if;
  logic        i1_valid_if;
  logic        spec0_en_if;
  logic        spec1_en_if;

  logic [31:0] i0_instr_id;
  logic [31:0] i1_instr_id;
  logic [31:0] i0_pc_id;
  logic [31:0] i1_pc_id;
  logic [31:0] i0_pc_target_id;
  logic [31:0] i1_pc_target_id;
  logic        i0_valid_id;
  logic        i1_valid_id;
  logic        spec0_en_id;
  logic        spec1_en_id;

  // From decode target_predict — freezes PC on nested speculation (not dispatch_stall).
  logic        i0_spec_stall_dec;
  logic        i1_spec_stall_dec;

  assign i0_pc_if = pc_fetch;
  assign i1_pc_if = pc_fetch_plus4;

  s1_fetch_struct #(
    .RESET_PC(RESET_PC)
  ) u_fetch (
    // external controls
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    // internal controls
    .dispatch_stall   (stall_id),
    .spec0_stall      (i0_spec_stall_dec),
    .spec1_stall      (i1_spec_stall_dec),
    .i0_pred_taken    (i0_pred_taken),
    .i1_pred_taken    (i1_pred_taken),
    .i0_brch_recover  (i0_brch_recover),
    .i1_brch_recover  (i1_brch_recover),
    // input data
    .i0_pc_execute    (i0_pc_execute),
    .i1_pc_execute    (i1_pc_execute),
    .i0_valid_wb      (i0_br_valid_wb),
    .i1_valid_wb      (i1_br_valid_wb),
    .i0_pc_wb         (i0_btb_pc_wb),
    .i1_pc_wb         (i1_btb_pc_wb),
    .i0_pc_target_wb  (i0_pc_target_wb),
    .i1_pc_target_wb  (i1_pc_target_wb),
    // output data
    .pc0              (pc_fetch),
    .pc1              (pc_fetch_plus4),
    .i0_pc_target     (i0_pc_target_if),
    .i1_pc_target     (i1_pc_target_if),
    .instr0           (i0_instr_if),
    .instr1           (i1_instr_if),
    // output controls
    .spec0_en         (spec0_en_if),
    .spec1_en         (spec1_en_if),
    .i0_valid         (i0_valid_if),
    .i1_valid         (i1_valid_if)
  );

  if_id u_if_id (
    // external controls
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    // internal controls
    .flush            (flush_core),
    .stall            (stall_id),
    .i0_valid_if      (i0_valid_if),
    .i1_valid_if      (i1_valid_if),
    .spec0_en_if      (spec0_en_if),
    .spec1_en_if      (spec1_en_if),
    // input data
    .i0_instr_if      (i0_instr_if),
    .i1_instr_if      (i1_instr_if),
    .i0_pc_if         (i0_pc_if),
    .i1_pc_if         (i1_pc_if),
    .i0_pc_target_if  (i0_pc_target_if),
    .i1_pc_target_if  (i1_pc_target_if),
    // output data
    .i0_instr_id      (i0_instr_id),
    .i1_instr_id      (i1_instr_id),
    .i0_pc_id         (i0_pc_id),
    .i1_pc_id         (i1_pc_id),
    .i0_pc_target_id  (i0_pc_target_id),
    .i1_pc_target_id  (i1_pc_target_id),
    // output controls
    .i0_valid_id      (i0_valid_id),
    .i1_valid_id      (i1_valid_id),
    .spec0_en_id      (spec0_en_id),
    .spec1_en_id      (spec1_en_id)
  );

  // -------------------------------------------------------------------------
  // Decode — dual decoder + GPR
  // -------------------------------------------------------------------------
  logic        i0_valid_dec;
  logic        i0_brch_en_dec;
  logic        i0_jump_en_dec;
  logic        i0_lane_sel_dec;
  logic [6:0]  i0_opcode_dec;
  logic [2:0]  i0_funct3_dec;
  logic [6:0]  i0_funct7_dec;
  logic [4:0]  i0_rd_dec;
  logic [4:0]  i0_rs1_dec;
  logic [4:0]  i0_rs2_dec;
  logic [31:0] i0_imm_dec;
  logic        i0_rs1_use_dec;
  logic        i0_rs2_use_dec;
  logic        i0_reg_write_dec;

  logic        i1_valid_dec;
  logic        i1_brch_en_dec;
  logic        i1_jump_en_dec;
  logic        i1_lane_sel_dec;
  logic [6:0]  i1_opcode_dec;
  logic [2:0]  i1_funct3_dec;
  logic [6:0]  i1_funct7_dec;
  logic [4:0]  i1_rd_dec;
  logic [4:0]  i1_rs1_dec;
  logic [4:0]  i1_rs2_dec;
  logic [31:0] i1_imm_dec;
  logic        i1_rs1_use_dec;
  logic        i1_rs2_use_dec;
  logic        i1_reg_write_dec;

  word_t i0_rs1_data;
  word_t i0_rs2_data;
  word_t i1_rs1_data;
  word_t i1_rs2_data;

  word_t       i0_pc_predict_dec;
  word_t       i1_pc_predict_dec;
  logic        i0_predict_taken_dec;
  logic        i1_predict_taken_dec;
  logic        i0_tp_wb_valid_dec;
  logic        i1_tp_wb_valid_dec;

  br_state_t   i0_target_state;
  br_state_t   i1_target_state;
  br_state_t   i0_target_state_wb;
  br_state_t   i1_target_state_wb;

  // Nested branch/jump under unresolved speculation freezes PC via spec*_stall.
  s2_decode_struct u_decode (
    // external controls
    .clk             (clk),
    .rst_n           (rst_n),
    // IF/ID controls
    .i0_valid_id     (i0_valid_id),
    .i1_valid_id     (i1_valid_id),
    .spec0_en        (spec0_en_id),
    .spec1_en        (spec1_en_id),
    // GPR writeback
    .i0_wen          (i0_reg_write_wb),
    .i1_wen          (i1_reg_write_wb),
    // IF/ID data
    .i0_instr        (i0_instr_id),
    .i1_instr        (i1_instr_id),
    .i0_pc           (i0_pc_id),
    .i1_pc           (i1_pc_id),
    .i0_pc_target    (i0_pc_target_id),
    .i1_pc_target    (i1_pc_target_id),
    .i0_br_valid_wb  (i0_br_valid_wb),
    .i1_br_valid_wb  (i1_br_valid_wb),
    .i0_br_pc_wb     (i0_btb_pc_wb),
    .i1_br_pc_wb     (i1_btb_pc_wb),
    .i0_target_state_wb (i0_target_state_wb),
    .i1_target_state_wb (i1_target_state_wb),
    .i0_rd           (i0_rd_addr_wb),
    .i0_wdata        (i0_wdata_wb),
    .i1_rd           (i1_rd_addr_wb),
    .i1_wdata        (i1_wdata_wb),
    // output data
    .i0_lane_sel     (i0_lane_sel_dec),
    .i0_opcode       (i0_opcode_dec),
    .i0_funct3       (i0_funct3_dec),
    .i0_funct7       (i0_funct7_dec),
    .i0_rd_addr      (i0_rd_dec),
    .i0_rs1_addr     (i0_rs1_dec),
    .i0_rs2_addr     (i0_rs2_dec),
    .i0_imm          (i0_imm_dec),
    .i0_rs1_data     (i0_rs1_data),
    .i0_rs2_data     (i0_rs2_data),
    .i1_lane_sel     (i1_lane_sel_dec),
    .i1_opcode       (i1_opcode_dec),
    .i1_funct3       (i1_funct3_dec),
    .i1_funct7       (i1_funct7_dec),
    .i1_rd_addr      (i1_rd_dec),
    .i1_rs1_addr     (i1_rs1_dec),
    .i1_rs2_addr     (i1_rs2_dec),
    .i1_imm          (i1_imm_dec),
    .i1_rs1_data     (i1_rs1_data),
    .i1_rs2_data     (i1_rs2_data),
    // output controls
    .i0_valid        (i0_valid_dec),
    .i0_brch_en      (i0_brch_en_dec),
    .i0_jump_en      (i0_jump_en_dec),
    .i0_rs1_use      (i0_rs1_use_dec),
    .i0_rs2_use      (i0_rs2_use_dec),
    .i0_reg_write    (i0_reg_write_dec),
    .i1_valid        (i1_valid_dec),
    .i1_brch_en      (i1_brch_en_dec),
    .i1_jump_en      (i1_jump_en_dec),
    .i1_rs1_use      (i1_rs1_use_dec),
    .i1_rs2_use      (i1_rs2_use_dec),
    .i1_reg_write    (i1_reg_write_dec),
    // branch predict
    .i0_target_state (i0_target_state),
    .i1_target_state (i1_target_state),
    .i0_pc_predict   (i0_pc_predict_dec),
    .i1_pc_predict   (i1_pc_predict_dec),
    .i0_predict_taken (i0_predict_taken_dec),
    .i1_predict_taken (i1_predict_taken_dec),
    .i0_tp_wb_valid  (i0_tp_wb_valid_dec),
    .i1_tp_wb_valid  (i1_tp_wb_valid_dec),
    .i0_spec_stall   (i0_spec_stall_dec),
    .i1_spec_stall   (i1_spec_stall_dec)
  );

  // predict taken from target_predict (jumps + state[1] for branches)
  assign i0_pred_taken = i0_predict_taken_dec;
  assign i1_pred_taken = i1_predict_taken_dec;

  // -------------------------------------------------------------------------
  // Dispatch — id_dp + dispatch_core_struct (s3_dispatch)
  // id_dp latches decode controls/data plus rs_use, spec*_en, and BHT state.
  // -------------------------------------------------------------------------

  // id_dp outputs — I0 controls
  logic        i0_valid_dp;
  logic        i0_lane_sel_dp;
  logic        i0_reg_write_dp;
  logic        i0_rs1_use_dp;
  logic        i0_rs2_use_dp;
  logic        spec0_en_dp;
  br_state_t   i0_state_dp;

  // id_dp outputs — I1 controls
  logic        i1_valid_dp;
  logic        i1_lane_sel_dp;
  logic        i1_reg_write_dp;
  logic        i1_rs1_use_dp;
  logic        i1_rs2_use_dp;
  logic        spec1_en_dp;
  br_state_t   i1_state_dp;

  // id_dp outputs — I0 data
  logic [6:0]  i0_opcode_dp;
  logic [2:0]  i0_funct3_dp;
  logic [6:0]  i0_funct7_dp;
  logic [4:0]  i0_rd_addr_dp;
  logic [4:0]  i0_rs1_addr_dp;
  logic [4:0]  i0_rs2_addr_dp;
  logic [31:0] i0_imm_dp;
  logic [31:0] i0_rs1_data_dp;
  logic [31:0] i0_rs2_data_dp;
  logic [31:0] i0_pc_dp;

  // id_dp outputs — I1 data
  logic [6:0]  i1_opcode_dp;
  logic [2:0]  i1_funct3_dp;
  logic [6:0]  i1_funct7_dp;
  logic [4:0]  i1_rd_addr_dp;
  logic [4:0]  i1_rs1_addr_dp;
  logic [4:0]  i1_rs2_addr_dp;
  logic [31:0] i1_imm_dp;
  logic [31:0] i1_rs1_data_dp;
  logic [31:0] i1_rs2_data_dp;
  logic [31:0] i1_pc_dp;

  logic        i0_reg_write_ex;
  logic        i1_reg_write_ex;
  logic [31:0] i0_pc_ex;
  logic [31:0] i1_pc_ex;

  logic        ev0_enable_ex;
  logic [6:0]  ev0_opcode_ex;
  logic [2:0]  ev0_funct3_ex;
  logic [6:0]  ev0_funct7_ex;
  logic [4:0]  ev0_rd_ex;
  logic [4:0]  ev0_rs1_addr_ex;
  logic [4:0]  ev0_rs2_addr_ex;
  logic [31:0] ev0_imm_ex;
  logic [31:0] ev0_rs1_data_ex;
  logic [31:0] ev0_rs2_data_ex;
  logic [31:0] ev0_pc_ex;

  logic        ev1_enable_ex;
  logic [6:0]  ev1_opcode_ex;
  logic [2:0]  ev1_funct3_ex;
  logic [6:0]  ev1_funct7_ex;
  logic [4:0]  ev1_rd_ex;
  logic [4:0]  ev1_rs1_addr_ex;
  logic [4:0]  ev1_rs2_addr_ex;
  logic [31:0] ev1_imm_ex;
  logic [31:0] ev1_rs1_data_ex;
  logic [31:0] ev1_rs2_data_ex;
  logic [31:0] ev1_pc_ex;

  logic        od0_enable_ex;
  logic [6:0]  od0_opcode_ex;
  logic [2:0]  od0_funct3_ex;
  logic [4:0]  od0_rd_ex;
  logic [4:0]  od0_rs1_addr_ex;
  logic [4:0]  od0_rs2_addr_ex;
  logic [31:0] od0_imm_ex;
  logic [31:0] od0_rs1_data_ex;
  logic [31:0] od0_rs2_data_ex;
  logic [31:0] od0_pc_ex;

  logic        od1_enable_ex;
  logic [6:0]  od1_opcode_ex;
  logic [2:0]  od1_funct3_ex;
  logic [4:0]  od1_rd_ex;
  logic [4:0]  od1_rs1_addr_ex;
  logic [4:0]  od1_rs2_addr_ex;
  logic [31:0] od1_imm_ex;
  logic [31:0] od1_rs1_data_ex;
  logic [31:0] od1_rs2_data_ex;
  logic [31:0] od1_pc_ex;

  logic [31:0] od0_load_mem_data;
  logic [31:0] od1_load_mem_data;

  logic        wb_push0_valid;
  logic [4:0]  wb_push0_rd;
  logic [31:0] wb_push0_wdata;
  logic [31:0] wb_push0_pc;
  logic        wb_push1_valid;
  logic [4:0]  wb_push1_rd;
  logic [31:0] wb_push1_wdata;
  logic [31:0] wb_push1_pc;

  id_dp u_id_dp (
    // external controls
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    // stage controls
    .flush           (flush_core),
    .stall           (stall_id),
    // I0 controls in (decode + IF/ID spec + BHT)
    .i0_valid_id     (i0_valid_dec),
    .i0_lane_sel_id  (i0_lane_sel_dec),
    .i0_reg_write_id (i0_reg_write_dec),
    .i0_rs1_use_id   (i0_rs1_use_dec),
    .i0_rs2_use_id   (i0_rs2_use_dec),
    .spec0_en_id     (spec0_en_id),
    .i0_state_id     (i0_target_state),
    // I1 controls in
    .i1_valid_id     (i1_valid_dec),
    .i1_lane_sel_id  (i1_lane_sel_dec),
    .i1_reg_write_id (i1_reg_write_dec),
    .i1_rs1_use_id   (i1_rs1_use_dec),
    .i1_rs2_use_id   (i1_rs2_use_dec),
    .spec1_en_id     (spec1_en_id),
    .i1_state_id     (i1_target_state),
    // I0 data in
    .i0_opcode_id    (i0_opcode_dec),
    .i0_funct3_id    (i0_funct3_dec),
    .i0_funct7_id    (i0_funct7_dec),
    .i0_rd_addr_id   (i0_rd_dec),
    .i0_rs1_addr_id  (i0_rs1_dec),
    .i0_rs2_addr_id  (i0_rs2_dec),
    .i0_imm_id       (i0_imm_dec),
    .i0_rs1_data_id  (i0_rs1_data),
    .i0_rs2_data_id  (i0_rs2_data),
    .i0_pc_id        (i0_pc_id),
    // I1 data in
    .i1_opcode_id    (i1_opcode_dec),
    .i1_funct3_id    (i1_funct3_dec),
    .i1_funct7_id    (i1_funct7_dec),
    .i1_rd_addr_id   (i1_rd_dec),
    .i1_rs1_addr_id  (i1_rs1_dec),
    .i1_rs2_addr_id  (i1_rs2_dec),
    .i1_imm_id       (i1_imm_dec),
    .i1_rs1_data_id  (i1_rs1_data),
    .i1_rs2_data_id  (i1_rs2_data),
    .i1_pc_id        (i1_pc_id),
    // I0 controls out
    .i0_valid_dp     (i0_valid_dp),
    .i0_lane_sel_dp  (i0_lane_sel_dp),
    .i0_reg_write_dp (i0_reg_write_dp),
    .i0_rs1_use_dp   (i0_rs1_use_dp),
    .i0_rs2_use_dp   (i0_rs2_use_dp),
    .spec0_en_dp     (spec0_en_dp),
    .i0_state_dp     (i0_state_dp),
    // I1 controls out
    .i1_valid_dp     (i1_valid_dp),
    .i1_lane_sel_dp  (i1_lane_sel_dp),
    .i1_reg_write_dp (i1_reg_write_dp),
    .i1_rs1_use_dp   (i1_rs1_use_dp),
    .i1_rs2_use_dp   (i1_rs2_use_dp),
    .spec1_en_dp     (spec1_en_dp),
    .i1_state_dp     (i1_state_dp),
    // I0 data out
    .i0_opcode_dp    (i0_opcode_dp),
    .i0_funct3_dp    (i0_funct3_dp),
    .i0_funct7_dp    (i0_funct7_dp),
    .i0_rd_addr_dp   (i0_rd_addr_dp),
    .i0_rs1_addr_dp  (i0_rs1_addr_dp),
    .i0_rs2_addr_dp  (i0_rs2_addr_dp),
    .i0_imm_dp       (i0_imm_dp),
    .i0_rs1_data_dp  (i0_rs1_data_dp),
    .i0_rs2_data_dp  (i0_rs2_data_dp),
    .i0_pc_dp        (i0_pc_dp),
    // I1 data out
    .i1_opcode_dp    (i1_opcode_dp),
    .i1_funct3_dp    (i1_funct3_dp),
    .i1_funct7_dp    (i1_funct7_dp),
    .i1_rd_addr_dp   (i1_rd_addr_dp),
    .i1_rs1_addr_dp  (i1_rs1_addr_dp),
    .i1_rs2_addr_dp  (i1_rs2_addr_dp),
    .i1_imm_dp       (i1_imm_dp),
    .i1_rs1_data_dp  (i1_rs1_data_dp),
    .i1_rs2_data_dp  (i1_rs2_data_dp),
    .i1_pc_dp        (i1_pc_dp)
  );

  // spec*_en_dp / i*_state_dp / i0_rs*_use_dp reserved for EX/MEM predictor train.
  // Dispatch currently consumes the classic decode bundle (+ I1 rs_use ports).
  dispatch_core_struct u_dispatch (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .flush               (flush_core),
    .commit_en           (1'b0),
    .commit_count        (2'd0),
    .set_complete_en     (1'b0),
    .set_complete_idx    (4'd0),
    .set_complete_result (32'd0),
    .i0_valid_dp         (i0_valid_dp),
    .i0_lane_sel_dp      (i0_lane_sel_dp),
    .i0_reg_write_dp     (i0_reg_write_dp),
    .i1_valid_dp         (i1_valid_dp),
    .i1_lane_sel_dp      (i1_lane_sel_dp),
    .i1_rs1_use_dp       (i1_rs1_use_dp),
    .i1_rs2_use_dp       (i1_rs2_use_dp),
    .i1_reg_write_dp     (i1_reg_write_dp),
    .i0_opcode_dp        (i0_opcode_dp),
    .i0_funct3_dp        (i0_funct3_dp),
    .i0_funct7_dp        (i0_funct7_dp),
    .i0_rd_addr_dp       (i0_rd_addr_dp),
    .i0_rs1_addr_dp      (i0_rs1_addr_dp),
    .i0_rs2_addr_dp      (i0_rs2_addr_dp),
    .i0_imm_dp           (i0_imm_dp),
    .i0_rs1_data_dp      (i0_rs1_data_dp),
    .i0_rs2_data_dp      (i0_rs2_data_dp),
    .i0_pc_dp            (i0_pc_dp),
    .i1_opcode_dp        (i1_opcode_dp),
    .i1_funct3_dp        (i1_funct3_dp),
    .i1_funct7_dp        (i1_funct7_dp),
    .i1_rd_addr_dp       (i1_rd_addr_dp),
    .i1_rs1_addr_dp      (i1_rs1_addr_dp),
    .i1_rs2_addr_dp      (i1_rs2_addr_dp),
    .i1_imm_dp           (i1_imm_dp),
    .i1_rs1_data_dp      (i1_rs1_data_dp),
    .i1_rs2_data_dp      (i1_rs2_data_dp),
    .i1_pc_dp            (i1_pc_dp),
    .stall_id            (stall_id),
    .i0_reg_write_disp   (i0_reg_write_ex),
    .i1_reg_write_disp   (i1_reg_write_ex),
    .i0_pc_disp          (i0_pc_ex),
    .i1_pc_disp          (i1_pc_ex),
    .ev0_enable_disp     (ev0_enable_ex),
    .ev0_opcode_disp     (ev0_opcode_ex),
    .ev0_funct3_disp     (ev0_funct3_ex),
    .ev0_funct7_disp     (ev0_funct7_ex),
    .ev0_rd_disp         (ev0_rd_ex),
    .ev0_rs1_addr_disp   (ev0_rs1_addr_ex),
    .ev0_rs2_addr_disp   (ev0_rs2_addr_ex),
    .ev0_imm_disp        (ev0_imm_ex),
    .ev0_rs1_data_disp   (ev0_rs1_data_ex),
    .ev0_rs2_data_disp   (ev0_rs2_data_ex),
    .ev0_pc_disp         (ev0_pc_ex),
    .ev1_enable_disp     (ev1_enable_ex),
    .ev1_opcode_disp     (ev1_opcode_ex),
    .ev1_funct3_disp     (ev1_funct3_ex),
    .ev1_funct7_disp     (ev1_funct7_ex),
    .ev1_rd_disp         (ev1_rd_ex),
    .ev1_rs1_addr_disp   (ev1_rs1_addr_ex),
    .ev1_rs2_addr_disp   (ev1_rs2_addr_ex),
    .ev1_imm_disp        (ev1_imm_ex),
    .ev1_rs1_data_disp   (ev1_rs1_data_ex),
    .ev1_rs2_data_disp   (ev1_rs2_data_ex),
    .ev1_pc_disp         (ev1_pc_ex),
    .od0_enable_disp     (od0_enable_ex),
    .od0_opcode_disp     (od0_opcode_ex),
    .od0_funct3_disp     (od0_funct3_ex),
    .od0_rd_disp         (od0_rd_ex),
    .od0_rs1_addr_disp   (od0_rs1_addr_ex),
    .od0_rs2_addr_disp   (od0_rs2_addr_ex),
    .od0_imm_disp        (od0_imm_ex),
    .od0_rs1_data_disp   (od0_rs1_data_ex),
    .od0_rs2_data_disp   (od0_rs2_data_ex),
    .od0_pc_disp         (od0_pc_ex),
    .od1_enable_disp     (od1_enable_ex),
    .od1_opcode_disp     (od1_opcode_ex),
    .od1_funct3_disp     (od1_funct3_ex),
    .od1_rd_disp         (od1_rd_ex),
    .od1_rs1_addr_disp   (od1_rs1_addr_ex),
    .od1_rs2_addr_disp   (od1_rs2_addr_ex),
    .od1_imm_disp        (od1_imm_ex),
    .od1_rs1_data_disp   (od1_rs1_data_ex),
    .od1_rs2_data_disp   (od1_rs2_data_ex),
    .od1_pc_disp         (od1_pc_ex)
  );

  // -------------------------------------------------------------------------
  // Execute — forward unit + four lanes
  // -------------------------------------------------------------------------
  logic [31:0] ev0_alu_result;
  logic [31:0] ev1_alu_result;

  logic        od0_use_link_ex;
  logic        od1_use_link_ex;
  logic        od0_brch_taken;
  logic [31:0] od0_brch_pc;
  logic        od0_mem_en;
  logic        od0_mem_write;
  logic [31:0] od0_mem_addr;
  logic [31:0] od0_mem_wdata;
  logic [3:0]  od0_mem_besel;
  logic [31:0] od0_link_pc;
  logic [31:0] od0_alu_result;

  logic        od1_brch_taken;
  logic [31:0] od1_brch_pc;
  logic        od1_mem_en;
  logic        od1_mem_write;
  logic [31:0] od1_mem_addr;
  logic [31:0] od1_mem_wdata;
  logic [3:0]  od1_mem_besel;
  logic [31:0] od1_link_pc;
  logic [31:0] od1_alu_result;

  logic        od0_use_link_mem;
  logic        od1_use_link_mem;
  logic        od0_reg_write_mem;
  logic [4:0]  od0_rd_mem;
  logic        od0_brch_taken_mem;
  logic [31:0] od0_brch_pc_mem;
  logic        od0_mem_en_mem;
  logic        od0_mem_write_mem;
  logic [31:0] od0_mem_addr_mem;
  logic [31:0] od0_mem_wdata_mem;
  logic [3:0]  od0_mem_besel_mem;
  logic [31:0] od0_link_pc_mem;
  logic [31:0] od0_alu_result_mem;
  logic [31:0] od0_pc_mem;

  logic        od1_reg_write_mem;
  logic [4:0]  od1_rd_mem;
  logic        od1_brch_taken_mem;
  logic [31:0] od1_brch_pc_mem;
  logic        od1_mem_en_mem;
  logic        od1_mem_write_mem;
  logic [31:0] od1_mem_addr_mem;
  logic [31:0] od1_mem_wdata_mem;
  logic [3:0]  od1_mem_besel_mem;
  logic [31:0] od1_link_pc_mem;
  logic [31:0] od1_alu_result_mem;
  logic [31:0] od1_pc_mem;

  logic        dcache_busy;

  s4_execute_struct u_execute (
    // external controls
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .flush               (flush_core),
    // internal controls
    .i0_reg_write_ex     (i0_reg_write_ex),
    .i1_reg_write_ex     (i1_reg_write_ex),
    .ev0_enable_ex       (ev0_enable_ex),
    .ev1_enable_ex       (ev1_enable_ex),
    .od0_enable_ex       (od0_enable_ex),
    .od1_enable_ex       (od1_enable_ex),
    .wb0_reg_write       (i0_reg_write_wb),
    .wb1_reg_write       (i1_reg_write_wb),
    // input data
    .i0_pc_ex            (i0_pc_ex),
    .i1_pc_ex            (i1_pc_ex),
    .ev0_opcode_ex       (ev0_opcode_ex),
    .ev0_funct3_ex       (ev0_funct3_ex),
    .ev0_funct7_ex       (ev0_funct7_ex),
    .ev0_rd_ex           (ev0_rd_ex),
    .ev0_rs1_addr_ex     (ev0_rs1_addr_ex),
    .ev0_rs2_addr_ex     (ev0_rs2_addr_ex),
    .ev0_imm_ex          (ev0_imm_ex),
    .ev0_rs1_data_ex     (ev0_rs1_data_ex),
    .ev0_rs2_data_ex     (ev0_rs2_data_ex),
    .ev0_pc_ex           (ev0_pc_ex),
    .ev1_opcode_ex       (ev1_opcode_ex),
    .ev1_funct3_ex       (ev1_funct3_ex),
    .ev1_funct7_ex       (ev1_funct7_ex),
    .ev1_rd_ex           (ev1_rd_ex),
    .ev1_rs1_addr_ex     (ev1_rs1_addr_ex),
    .ev1_rs2_addr_ex     (ev1_rs2_addr_ex),
    .ev1_imm_ex          (ev1_imm_ex),
    .ev1_rs1_data_ex     (ev1_rs1_data_ex),
    .ev1_rs2_data_ex     (ev1_rs2_data_ex),
    .ev1_pc_ex           (ev1_pc_ex),
    .od0_opcode_ex       (od0_opcode_ex),
    .od0_funct3_ex       (od0_funct3_ex),
    .od0_rd_ex           (od0_rd_ex),
    .od0_rs1_addr_ex     (od0_rs1_addr_ex),
    .od0_rs2_addr_ex     (od0_rs2_addr_ex),
    .od0_imm_ex          (od0_imm_ex),
    .od0_rs1_data_ex     (od0_rs1_data_ex),
    .od0_rs2_data_ex     (od0_rs2_data_ex),
    .od0_pc_ex           (od0_pc_ex),
    .od1_opcode_ex       (od1_opcode_ex),
    .od1_funct3_ex       (od1_funct3_ex),
    .od1_rd_ex           (od1_rd_ex),
    .od1_rs1_addr_ex     (od1_rs1_addr_ex),
    .od1_rs2_addr_ex     (od1_rs2_addr_ex),
    .od1_imm_ex          (od1_imm_ex),
    .od1_rs1_data_ex     (od1_rs1_data_ex),
    .od1_rs2_data_ex     (od1_rs2_data_ex),
    .od1_pc_ex           (od1_pc_ex),
    .wb0_rd_addr         (i0_rd_addr_wb),
    .wb0_data            (i0_wdata_wb),
    .wb0_pc              (i0_gpr_wpc),
    .wb1_rd_addr         (i1_rd_addr_wb),
    .wb1_data            (i1_wdata_wb),
    .wb1_pc              (i1_gpr_wpc),
    // output controls
    .od0_use_link_ex     (od0_use_link_ex),
    .od1_use_link_ex     (od1_use_link_ex),
    .od0_brch_taken      (od0_brch_taken),
    .od0_mem_en          (od0_mem_en),
    .od0_mem_write         (od0_mem_write),
    .od1_brch_taken      (od1_brch_taken),
    .od1_mem_en          (od1_mem_en),
    .od1_mem_write         (od1_mem_write),
    // output data
    .ev0_alu_result      (ev0_alu_result),
    .ev1_alu_result      (ev1_alu_result),
    .od0_brch_pc         (od0_brch_pc),
    .od0_mem_addr        (od0_mem_addr),
    .od0_mem_wdata       (od0_mem_wdata),
    .od0_mem_besel       (od0_mem_besel),
    .od0_link_pc         (od0_link_pc),
    .od0_alu_result      (od0_alu_result),
    .od1_brch_pc         (od1_brch_pc),
    .od1_mem_addr        (od1_mem_addr),
    .od1_mem_wdata       (od1_mem_wdata),
    .od1_mem_besel       (od1_mem_besel),
    .od1_link_pc         (od1_link_pc),
    .od1_alu_result      (od1_alu_result)
  );

  // -------------------------------------------------------------------------
  // EX/MEM — odd-lane pipeline register (s5)
  // -------------------------------------------------------------------------
  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .stall_od0           (dcache_busy && od0_mem_en_mem),
    .stall_od1           (dcache_busy && od1_mem_en_mem),
    .od0_enable_ex       (od0_enable_ex),
    .od0_reg_write_ex    (i0_reg_write_ex),
    .od0_rd_ex           (od0_rd_ex),
    .od0_brch_taken_ex   (od0_brch_taken),
    .od0_brch_pc_ex      (od0_brch_pc),
    .od0_mem_en_ex       (od0_mem_en),
    .od0_mem_write_ex      (od0_mem_write),
    .od0_mem_addr_ex     (od0_mem_addr),
    .od0_mem_wdata_ex    (od0_mem_wdata),
    .od0_mem_besel_ex    (od0_mem_besel),
    .od0_link_pc_ex      (od0_link_pc),
    .od0_alu_result_ex   (od0_alu_result),
    .od0_use_link_ex     (od0_use_link_ex),
    .od0_pc_ex           (od0_pc_ex),
    .od1_enable_ex       (od1_enable_ex),
    .od1_reg_write_ex    (i1_reg_write_ex),
    .od1_rd_ex           (od1_rd_ex),
    .od1_brch_taken_ex   (od1_brch_taken),
    .od1_brch_pc_ex      (od1_brch_pc),
    .od1_mem_en_ex       (od1_mem_en),
    .od1_mem_write_ex      (od1_mem_write),
    .od1_mem_addr_ex     (od1_mem_addr),
    .od1_mem_wdata_ex    (od1_mem_wdata),
    .od1_mem_besel_ex    (od1_mem_besel),
    .od1_link_pc_ex      (od1_link_pc),
    .od1_alu_result_ex   (od1_alu_result),
    .od1_use_link_ex     (od1_use_link_ex),
    .od1_pc_ex           (od1_pc_ex),
    .od0_reg_write_mem   (od0_reg_write_mem),
    .od0_rd_mem          (od0_rd_mem),
    .od0_brch_taken_mem  (od0_brch_taken_mem),
    .od0_brch_pc_mem     (od0_brch_pc_mem),
    .od0_mem_en_mem      (od0_mem_en_mem),
    .od0_mem_write_mem     (od0_mem_write_mem),
    .od0_mem_addr_mem    (od0_mem_addr_mem),
    .od0_mem_wdata_mem   (od0_mem_wdata_mem),
    .od0_mem_besel_mem   (od0_mem_besel_mem),
    .od0_link_pc_mem     (od0_link_pc_mem),
    .od0_alu_result_mem  (od0_alu_result_mem),
    .od0_use_link_mem    (od0_use_link_mem),
    .od0_pc_mem          (od0_pc_mem),
    .od1_reg_write_mem   (od1_reg_write_mem),
    .od1_rd_mem          (od1_rd_mem),
    .od1_brch_taken_mem  (od1_brch_taken_mem),
    .od1_brch_pc_mem     (od1_brch_pc_mem),
    .od1_mem_en_mem      (od1_mem_en_mem),
    .od1_mem_write_mem     (od1_mem_write_mem),
    .od1_mem_addr_mem    (od1_mem_addr_mem),
    .od1_mem_wdata_mem   (od1_mem_wdata_mem),
    .od1_mem_besel_mem   (od1_mem_besel_mem),
    .od1_link_pc_mem     (od1_link_pc_mem),
    .od1_alu_result_mem  (od1_alu_result_mem),
    .od1_use_link_mem    (od1_use_link_mem),
    .od1_pc_mem          (od1_pc_mem)
  );

  // Branch resolve → fetch redirect (odd lanes at MEM)
  assign i0_brch_recover = od0_brch_taken_mem;
  assign i1_brch_recover = od1_brch_taken_mem;
  assign i0_pc_execute   = od0_brch_pc_mem;
  assign i1_pc_execute   = od1_brch_pc_mem;
  assign br_recover      = i0_brch_recover | i1_brch_recover;
  assign flush_core      = flush | br_recover;

  assign i0_br_valid_wb     = od0_brch_taken_mem;
  assign i1_br_valid_wb     = od1_brch_taken_mem;
  assign i0_btb_pc_wb       = od0_pc_mem;
  assign i1_btb_pc_wb       = od1_pc_mem;
  assign i0_pc_target_wb    = od0_brch_pc_mem;
  assign i1_pc_target_wb    = od1_brch_pc_mem;

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

  // -------------------------------------------------------------------------
  // Memory — L1 data cache (s5)
  // -------------------------------------------------------------------------
  s5_memory_struct u_memory (
    // external controls
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    // internal controls
    .od0_mem_en_mem    (od0_mem_en_mem),
    .od0_mem_write_mem   (od0_mem_write_mem),
    .od1_mem_en_mem    (od1_mem_en_mem),
    .od1_mem_write_mem   (od1_mem_write_mem),
    // input data
    .od0_mem_addr_mem  (od0_mem_addr_mem),
    .od0_mem_wdata_mem (od0_mem_wdata_mem),
    .od0_mem_besel_mem (od0_mem_besel_mem),
    .od1_mem_addr_mem  (od1_mem_addr_mem),
    .od1_mem_wdata_mem (od1_mem_wdata_mem),
    .od1_mem_besel_mem (od1_mem_besel_mem),
    // output data
    .od0_load_mem_data (od0_load_mem_data),
    .od1_load_mem_data (od1_load_mem_data),
    // output controls
    .dcache_busy       (dcache_busy)
  );

  // -------------------------------------------------------------------------
  // EX/WB + MEM/WB — even EX bank + odd MEM bank (s6)
  // -------------------------------------------------------------------------
  ex_mem_wb u_ex_mem_wb (
    .clk                (clk),
    .rst_n              (rst_n),
    .enable             (enable),
    .flush              (flush_core),
    .ev0_reg_write_ex   (ev0_enable_ex && i0_reg_write_ex),
    .ev0_rd_addr_ex     (ev0_rd_ex),
    .ev0_wdata_ex       (ev0_alu_result),
    .ev0_pc_ex          (ev0_pc_ex),
    .ev1_reg_write_ex   (ev1_enable_ex && i1_reg_write_ex),
    .ev1_rd_addr_ex     (ev1_rd_ex),
    .ev1_wdata_ex       (ev1_alu_result),
    .ev1_pc_ex          (ev1_pc_ex),
    .od0_reg_write_mem  (od0_reg_write_mem),
    .od0_rd_addr_mem    (od0_rd_mem),
    .od0_pc_mem         (od0_pc_mem),
    .od0_use_link_mem   (od0_use_link_mem),
    .od0_alu_result_mem (od0_alu_result_mem),
    .od0_mem_en_mem     (od0_mem_en_mem),
    .od0_mem_write_mem    (od0_mem_write_mem),
    .od0_load_mem_data     (od0_load_mem_data),
    .od1_reg_write_mem  (od1_reg_write_mem),
    .od1_rd_addr_mem    (od1_rd_mem),
    .od1_pc_mem         (od1_pc_mem),
    .od1_use_link_mem   (od1_use_link_mem),
    .od1_alu_result_mem (od1_alu_result_mem),
    .od1_mem_en_mem     (od1_mem_en_mem),
    .od1_mem_write_mem    (od1_mem_write_mem),
    .od1_load_mem_data     (od1_load_mem_data),
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
    .push0_rd           (wb_push0_rd),
    .push0_wdata        (wb_push0_wdata),
    .push0_pc           (wb_push0_pc),
    .push1_valid        (wb_push1_valid),
    .push1_rd           (wb_push1_rd),
    .push1_wdata        (wb_push1_wdata),
    .push1_pc           (wb_push1_pc)
  );

  assign i0_reg_write_wb = wb_push0_valid;
  assign i0_rd_addr_wb   = wb_push0_rd;
  assign i0_wdata_wb     = wb_push0_wdata;
  assign i0_gpr_wpc      = wb_push0_pc;
  assign i1_reg_write_wb = wb_push1_valid;
  assign i1_rd_addr_wb   = wb_push1_rd;
  assign i1_wdata_wb     = wb_push1_wdata;
  assign i1_gpr_wpc      = wb_push1_pc;

endmodule
