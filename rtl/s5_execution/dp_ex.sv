`timescale 1ns / 1ps

// DP/EX pipeline register: dual RS issue + PRF data → four EX ports by lane_sel.
//   lane_sel=0 → even (ev0 then ev1); lane_sel=1 → odd (od0 then od1).
// Operand values from the PRF are buffered here (not in the reservation station).
// prd is the ROB-owned dest tag (same as ROB index).
import rv_dis_pkg::*;

module dp_ex (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,

  input  logic        valid_iss     [2],
  input  logic        lane_sel_iss  [2],
  input  logic        reg_write_iss [2],
  input  opcode_t     opcode_iss    [2],
  input  funct3_t     funct3_iss    [2],
  input  funct7_t     funct7_iss    [2],
  input  prf_addr_t   prd_iss       [2],
  input  word_t       imm_iss       [2],
  input  word_t       pc_iss        [2],
  input  word_t       rs1_data      [2],
  input  word_t       rs2_data      [2],

  output logic        ev0_enable_ex,
  output logic        ev0_reg_write_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output prf_addr_t   ev0_prd_ex,
  output word_t       ev0_imm_ex,
  output word_t       ev0_pc_ex,
  output word_t       ev0_rs1_data_ex,
  output word_t       ev0_rs2_data_ex,

  output logic        ev1_enable_ex,
  output logic        ev1_reg_write_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output prf_addr_t   ev1_prd_ex,
  output word_t       ev1_imm_ex,
  output word_t       ev1_pc_ex,
  output word_t       ev1_rs1_data_ex,
  output word_t       ev1_rs2_data_ex,

  output logic        od0_enable_ex,
  output logic        od0_reg_write_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output prf_addr_t   od0_prd_ex,
  output word_t       od0_imm_ex,
  output word_t       od0_pc_ex,
  output word_t       od0_rs1_data_ex,
  output word_t       od0_rs2_data_ex,

  output logic        od1_enable_ex,
  output logic        od1_reg_write_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output prf_addr_t   od1_prd_ex,
  output word_t       od1_imm_ex,
  output word_t       od1_pc_ex,
  output word_t       od1_rs1_data_ex,
  output word_t       od1_rs2_data_ex
);

  // EX port ordering held internally; the four flat output groups are the
  // lane demux seen by execute.
  localparam int N_PORT   = 4;
  localparam int P_EV0    = 0;
  localparam int P_EV1    = 1;
  localparam int P_OD0    = 2;
  localparam int P_OD1    = 3;
  localparam int P_NONE   = 4;

  int port_sel [2];

  // Slot 0 takes the first port of its lane; slot 1 spills to the second.
  always_comb begin
    logic even_used, odd_used;
    even_used = 1'b0;
    odd_used  = 1'b0;
    for (int i = 0; i < N_DUAL; i++) begin
      port_sel[i] = P_NONE;
      if (valid_iss[i]) begin
        if (lane_sel_iss[i] == 1'b0) begin
          port_sel[i] = even_used ? P_EV1 : P_EV0;
          even_used   = 1'b1;
        end else begin
          port_sel[i] = odd_used ? P_OD1 : P_OD0;
          odd_used    = 1'b1;
        end
      end
    end
  end

  logic      n_en  [N_PORT], n_rw  [N_PORT];
  opcode_t   n_op  [N_PORT];
  funct3_t   n_f3  [N_PORT];
  funct7_t   n_f7  [N_PORT];
  prf_addr_t n_prd [N_PORT];
  word_t     n_imm [N_PORT], n_pc [N_PORT], n_rs1 [N_PORT], n_rs2 [N_PORT];

  always_comb begin
    for (int p = 0; p < N_PORT; p++) begin
      n_en[p]  = 1'b0; n_rw[p]  = 1'b0;
      n_op[p]  = '0;   n_f3[p]  = '0;   n_f7[p] = '0;
      n_prd[p] = '0;   n_imm[p] = '0;   n_pc[p] = '0;
      n_rs1[p] = '0;   n_rs2[p] = '0;
    end
    for (int i = 0; i < N_DUAL; i++) begin
      if (port_sel[i] != P_NONE) begin
        n_en[port_sel[i]]  = 1'b1;
        n_rw[port_sel[i]]  = reg_write_iss[i];
        n_op[port_sel[i]]  = opcode_iss[i];
        n_f3[port_sel[i]]  = funct3_iss[i];
        n_f7[port_sel[i]]  = funct7_iss[i];
        n_prd[port_sel[i]] = prd_iss[i];
        n_imm[port_sel[i]] = imm_iss[i];
        n_pc[port_sel[i]]  = pc_iss[i];
        n_rs1[port_sel[i]] = rs1_data[i];
        n_rs2[port_sel[i]] = rs2_data[i];
      end
    end
  end

  logic      q_en  [N_PORT], q_rw  [N_PORT];
  opcode_t   q_op  [N_PORT];
  funct3_t   q_f3  [N_PORT];
  funct7_t   q_f7  [N_PORT];
  prf_addr_t q_prd [N_PORT];
  word_t     q_imm [N_PORT], q_pc [N_PORT], q_rs1 [N_PORT], q_rs2 [N_PORT];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int p = 0; p < N_PORT; p++) begin
        q_en[p]  <= 1'b0; q_rw[p]  <= 1'b0;
        q_op[p]  <= '0;   q_f3[p]  <= '0;   q_f7[p] <= '0;
        q_prd[p] <= '0;   q_imm[p] <= '0;   q_pc[p] <= '0;
        q_rs1[p] <= '0;   q_rs2[p] <= '0;
      end
    end else if (enable && !stall) begin
      for (int p = 0; p < N_PORT; p++) begin
        q_en[p]  <= n_en[p];  q_rw[p]  <= n_rw[p];
        q_op[p]  <= n_op[p];  q_f3[p]  <= n_f3[p];  q_f7[p] <= n_f7[p];
        q_prd[p] <= n_prd[p]; q_imm[p] <= n_imm[p]; q_pc[p] <= n_pc[p];
        q_rs1[p] <= n_rs1[p]; q_rs2[p] <= n_rs2[p];
      end
    end
  end

  assign ev0_enable_ex    = q_en[P_EV0];
  assign ev0_reg_write_ex = q_rw[P_EV0];
  assign ev0_opcode_ex    = q_op[P_EV0];
  assign ev0_funct3_ex    = q_f3[P_EV0];
  assign ev0_funct7_ex    = q_f7[P_EV0];
  assign ev0_prd_ex       = q_prd[P_EV0];
  assign ev0_imm_ex       = q_imm[P_EV0];
  assign ev0_pc_ex        = q_pc[P_EV0];
  assign ev0_rs1_data_ex  = q_rs1[P_EV0];
  assign ev0_rs2_data_ex  = q_rs2[P_EV0];

  assign ev1_enable_ex    = q_en[P_EV1];
  assign ev1_reg_write_ex = q_rw[P_EV1];
  assign ev1_opcode_ex    = q_op[P_EV1];
  assign ev1_funct3_ex    = q_f3[P_EV1];
  assign ev1_funct7_ex    = q_f7[P_EV1];
  assign ev1_prd_ex       = q_prd[P_EV1];
  assign ev1_imm_ex       = q_imm[P_EV1];
  assign ev1_pc_ex        = q_pc[P_EV1];
  assign ev1_rs1_data_ex  = q_rs1[P_EV1];
  assign ev1_rs2_data_ex  = q_rs2[P_EV1];

  assign od0_enable_ex    = q_en[P_OD0];
  assign od0_reg_write_ex = q_rw[P_OD0];
  assign od0_opcode_ex    = q_op[P_OD0];
  assign od0_funct3_ex    = q_f3[P_OD0];
  assign od0_prd_ex       = q_prd[P_OD0];
  assign od0_imm_ex       = q_imm[P_OD0];
  assign od0_pc_ex        = q_pc[P_OD0];
  assign od0_rs1_data_ex  = q_rs1[P_OD0];
  assign od0_rs2_data_ex  = q_rs2[P_OD0];

  assign od1_enable_ex    = q_en[P_OD1];
  assign od1_reg_write_ex = q_rw[P_OD1];
  assign od1_opcode_ex    = q_op[P_OD1];
  assign od1_funct3_ex    = q_f3[P_OD1];
  assign od1_prd_ex       = q_prd[P_OD1];
  assign od1_imm_ex       = q_imm[P_OD1];
  assign od1_pc_ex        = q_pc[P_OD1];
  assign od1_rs1_data_ex  = q_rs1[P_OD1];
  assign od1_rs2_data_ex  = q_rs2[P_OD1];

endmodule
