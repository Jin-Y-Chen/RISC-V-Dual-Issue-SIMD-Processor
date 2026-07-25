interface rename_if(input logic clk);
  import rv_dis_pkg::*;

  logic      rst_n;
  logic      flush;
  logic      spec0_en_rn, spec1_en_rn;

  logic      i0_valid_rn,     i1_valid_rn;
  logic      i0_lane_sel_rn,  i1_lane_sel_rn;
  logic      i0_reg_write_rn, i1_reg_write_rn;
  logic      i0_store_en_rn,  i1_store_en_rn;
  logic      i0_rs1_use_rn,   i0_rs2_use_rn;
  logic      i1_rs1_use_rn,   i1_rs2_use_rn;
  opcode_t   i0_opcode_rn,    i1_opcode_rn;
  funct3_t   i0_funct3_rn,    i1_funct3_rn;
  funct7_t   i0_funct7_rn,    i1_funct7_rn;
  gpr_addr_t i0_rd_addr_rn,   i0_rs1_addr_rn, i0_rs2_addr_rn;
  gpr_addr_t i1_rd_addr_rn,   i1_rs1_addr_rn, i1_rs2_addr_rn;
  word_t     i0_imm_rn,       i0_pc_rn;
  word_t     i1_imm_rn,       i1_pc_rn;

  logic      wback0_en, wback1_en;
  prf_addr_t i0_rob_idx_wb, i1_rob_idx_wb;
  logic      i0_brch_taken_wb, i1_brch_taken_wb;

  logic      stall_id;
  logic      i0_valid_disp, i1_valid_disp;
  logic      i0_lane_sel_disp, i1_lane_sel_disp;
  logic      i0_reg_write_disp, i1_reg_write_disp;
  opcode_t   i0_opcode_disp, i1_opcode_disp;
  funct3_t   i0_funct3_disp, i1_funct3_disp;
  funct7_t   i0_funct7_disp, i1_funct7_disp;
  gpr_addr_t i0_rd_addr_disp, i1_rd_addr_disp;
  prf_addr_t i0_ps1_disp, i0_ps2_disp, i0_prd_disp;
  prf_addr_t i1_ps1_disp, i1_ps2_disp, i1_prd_disp;
  prf_addr_t i0_rob_idx_disp, i1_rob_idx_disp;
  word_t     i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp;

  logic      retire0_en, retire1_en;
  logic      rrat0_en, rrat1_en;
  gpr_addr_t i0_rd_addr_cmt, i1_rd_addr_cmt;
  prf_addr_t i0_rob_idx_cmt, i1_rob_idx_cmt;
  logic      stb0_en, stb1_en;

  // The monitor samples the completed cycle just before negedge. Drivers then
  // launch the next transaction, which remains stable through the next posedge.
  clocking req_drv_cb @(negedge clk);
    default input #1step output #0;
    output flush, spec0_en_rn, spec1_en_rn;
    output i0_valid_rn, i1_valid_rn;
    output i0_lane_sel_rn, i1_lane_sel_rn;
    output i0_reg_write_rn, i1_reg_write_rn;
    output i0_store_en_rn, i1_store_en_rn;
    output i0_rs1_use_rn, i0_rs2_use_rn, i1_rs1_use_rn, i1_rs2_use_rn;
    output i0_opcode_rn, i1_opcode_rn, i0_funct3_rn, i1_funct3_rn;
    output i0_funct7_rn, i1_funct7_rn;
    output i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn;
    output i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn;
    output i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn;
  endclocking

  clocking wb_drv_cb @(negedge clk);
    default input #1step output #0;
    output wback0_en, wback1_en, i0_rob_idx_wb, i1_rob_idx_wb;
    output i0_brch_taken_wb, i1_brch_taken_wb;
  endclocking

  clocking mon_cb @(negedge clk);
    default input #1step;
    input rst_n, flush, spec0_en_rn, spec1_en_rn;
    input i0_valid_rn, i1_valid_rn;
    input i0_lane_sel_rn, i1_lane_sel_rn;
    input i0_reg_write_rn, i1_reg_write_rn;
    input i0_store_en_rn, i1_store_en_rn;
    input i0_rs1_use_rn, i0_rs2_use_rn, i1_rs1_use_rn, i1_rs2_use_rn;
    input i0_opcode_rn, i1_opcode_rn, i0_funct3_rn, i1_funct3_rn;
    input i0_funct7_rn, i1_funct7_rn;
    input i0_rd_addr_rn, i0_rs1_addr_rn, i0_rs2_addr_rn;
    input i1_rd_addr_rn, i1_rs1_addr_rn, i1_rs2_addr_rn;
    input i0_imm_rn, i0_pc_rn, i1_imm_rn, i1_pc_rn;
    input wback0_en, wback1_en, i0_rob_idx_wb, i1_rob_idx_wb;
    input i0_brch_taken_wb, i1_brch_taken_wb;
    input stall_id;
    input i0_valid_disp, i1_valid_disp;
    input i0_lane_sel_disp, i1_lane_sel_disp;
    input i0_reg_write_disp, i1_reg_write_disp;
    input i0_opcode_disp, i1_opcode_disp, i0_funct3_disp, i1_funct3_disp;
    input i0_funct7_disp, i1_funct7_disp;
    input i0_rd_addr_disp, i1_rd_addr_disp;
    input i0_ps1_disp, i0_ps2_disp, i0_prd_disp;
    input i1_ps1_disp, i1_ps2_disp, i1_prd_disp;
    input i0_rob_idx_disp, i1_rob_idx_disp;
    input i0_imm_disp, i1_imm_disp, i0_pc_disp, i1_pc_disp;
    input retire0_en, retire1_en;
    input rrat0_en, rrat1_en, i0_rd_addr_cmt, i1_rd_addr_cmt;
    input i0_rob_idx_cmt, i1_rob_idx_cmt;
    input stb0_en, stb1_en;
  endclocking

  modport req_driver(clocking req_drv_cb, input rst_n);
  modport wb_driver(clocking wb_drv_cb, input rst_n);
  modport monitor(clocking mon_cb);
endinterface
