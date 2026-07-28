`timescale 1ns / 1ps

// DP/EX pipeline register: dual RS issue + PRF data → even/odd EX ports by lane_sel.
//   lane_sel=0 → even (ev[0] then ev[1]); lane_sel=1 → odd (od[0] then od[1]).
// Operand values from the PRF are buffered here (not in the reservation station).
// rob_tag is the ROB-owned dest tag (same as ROB index).
import rv_dis_pkg::*;

module dp_ex (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,

  input  logic        rob_valid [2],
  input  logic        lane_sel  [2],
  input  opcode_t     opcode    [2],
  input  funct3_t     funct3    [2],
  input  funct7_t     funct7    [2],
  input  prf_addr_t   rob_tag   [2],
  input  word_t       imm       [2],
  input  word_t       pc        [2],
  input  word_t       rs1_data  [2],
  input  word_t       rs2_data  [2],

  output logic        ev_enable_ex    [2],
  output logic        ev_reg_write_ex [2],
  output opcode_t     ev_opcode_ex    [2],
  output funct3_t     ev_funct3_ex    [2],
  output funct7_t     ev_funct7_ex    [2],
  output prf_addr_t   ev_prd_ex       [2],
  output word_t       ev_imm_ex       [2],
  output word_t       ev_pc_ex        [2],
  output word_t       ev_rs1_data_ex  [2],
  output word_t       ev_rs2_data_ex  [2],

  output logic        od_enable_ex    [2],
  output logic        od_reg_write_ex [2],
  output opcode_t     od_opcode_ex    [2],
  output funct3_t     od_funct3_ex    [2],
  output prf_addr_t   od_prd_ex       [2],
  output word_t       od_imm_ex       [2],
  output word_t       od_pc_ex        [2],
  output word_t       od_rs1_data_ex  [2],
  output word_t       od_rs2_data_ex  [2]
);

  // Internal 4-port demux; unpacked to ev/od [2] at the EX boundary.
  localparam int N_PORT = 4;
  localparam int P_EV0  = 0;
  localparam int P_EV1  = 1;
  localparam int P_OD0  = 2;
  localparam int P_OD1  = 3;
  localparam int P_NONE = 4;

  int port_sel [2];

  // Slot 0 takes the first port of its lane; slot 1 spills to the second.
  always_comb begin
    logic even_used, odd_used;
    even_used = 1'b0;
    odd_used  = 1'b0;
    for (int i = 0; i < N_DUAL; i++) begin
      port_sel[i] = P_NONE;
      if (rob_valid[i]) begin
        if (lane_sel[i] == 1'b0) begin
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
        n_rw[port_sel[i]]  = (rob_tag[i] != '0);
        n_op[port_sel[i]]  = opcode[i];
        n_f3[port_sel[i]]  = funct3[i];
        n_f7[port_sel[i]]  = funct7[i];
        n_prd[port_sel[i]] = rob_tag[i];
        n_imm[port_sel[i]] = imm[i];
        n_pc[port_sel[i]]  = pc[i];
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

  for (genvar i = 0; i < N_DUAL; i++) begin : g_ev
    assign ev_enable_ex[i]    = q_en[P_EV0 + i];
    assign ev_reg_write_ex[i] = q_rw[P_EV0 + i];
    assign ev_opcode_ex[i]    = q_op[P_EV0 + i];
    assign ev_funct3_ex[i]    = q_f3[P_EV0 + i];
    assign ev_funct7_ex[i]    = q_f7[P_EV0 + i];
    assign ev_prd_ex[i]       = q_prd[P_EV0 + i];
    assign ev_imm_ex[i]       = q_imm[P_EV0 + i];
    assign ev_pc_ex[i]        = q_pc[P_EV0 + i];
    assign ev_rs1_data_ex[i]  = q_rs1[P_EV0 + i];
    assign ev_rs2_data_ex[i]  = q_rs2[P_EV0 + i];
  end

  for (genvar i = 0; i < N_DUAL; i++) begin : g_od
    assign od_enable_ex[i]    = q_en[P_OD0 + i];
    assign od_reg_write_ex[i] = q_rw[P_OD0 + i];
    assign od_opcode_ex[i]    = q_op[P_OD0 + i];
    assign od_funct3_ex[i]    = q_f3[P_OD0 + i];
    assign od_prd_ex[i]       = q_prd[P_OD0 + i];
    assign od_imm_ex[i]       = q_imm[P_OD0 + i];
    assign od_pc_ex[i]        = q_pc[P_OD0 + i];
    assign od_rs1_data_ex[i]  = q_rs1[P_OD0 + i];
    assign od_rs2_data_ex[i]  = q_rs2[P_OD0 + i];
  end

endmodule
