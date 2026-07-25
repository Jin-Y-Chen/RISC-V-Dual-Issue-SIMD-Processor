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

  input  logic        i0_valid_iss,
  input  logic        i0_lane_sel_iss,
  input  logic        i0_reg_write_iss,
  input  opcode_t     i0_opcode_iss,
  input  funct3_t     i0_funct3_iss,
  input  funct7_t     i0_funct7_iss,
  input  prf_addr_t   i0_prd_iss,
  input  word_t       i0_imm_iss,
  input  word_t       i0_pc_iss,
  input  word_t       i0_rs1_data,
  input  word_t       i0_rs2_data,

  input  logic        i1_valid_iss,
  input  logic        i1_lane_sel_iss,
  input  logic        i1_reg_write_iss,
  input  opcode_t     i1_opcode_iss,
  input  funct3_t     i1_funct3_iss,
  input  funct7_t     i1_funct7_iss,
  input  prf_addr_t   i1_prd_iss,
  input  word_t       i1_imm_iss,
  input  word_t       i1_pc_iss,
  input  word_t       i1_rs1_data,
  input  word_t       i1_rs2_data,

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

  logic [2:0] i0_port, i1_port;

  always_comb begin
    logic even_used, odd_used;
    i0_port = 3'd4;
    i1_port = 3'd4;
    even_used = 1'b0;
    odd_used  = 1'b0;

    if (i0_valid_iss) begin
      if (i0_lane_sel_iss == 1'b0) begin
        i0_port   = 3'd0;
        even_used = 1'b1;
      end else begin
        i0_port  = 3'd2;
        odd_used = 1'b1;
      end
    end

    if (i1_valid_iss) begin
      if (i1_lane_sel_iss == 1'b0)
        i1_port = even_used ? 3'd1 : 3'd0;
      else
        i1_port = odd_used ? 3'd3 : 3'd2;
    end
  end

  logic        n_ev0_en, n_ev1_en, n_od0_en, n_od1_en;
  logic        n_ev0_rw, n_ev1_rw, n_od0_rw, n_od1_rw;
  opcode_t     n_ev0_op, n_ev1_op, n_od0_op, n_od1_op;
  funct3_t     n_ev0_f3, n_ev1_f3, n_od0_f3, n_od1_f3;
  funct7_t     n_ev0_f7, n_ev1_f7;
  prf_addr_t   n_ev0_prd, n_ev1_prd, n_od0_prd, n_od1_prd;
  word_t       n_ev0_imm, n_ev1_imm, n_od0_imm, n_od1_imm;
  word_t       n_ev0_pc,  n_ev1_pc,  n_od0_pc,  n_od1_pc;
  word_t       n_ev0_rs1, n_ev1_rs1, n_od0_rs1, n_od1_rs1;
  word_t       n_ev0_rs2, n_ev1_rs2, n_od0_rs2, n_od1_rs2;

  always_comb begin
    n_ev0_en = 1'b0; n_ev1_en = 1'b0; n_od0_en = 1'b0; n_od1_en = 1'b0;
    n_ev0_rw = 1'b0; n_ev1_rw = 1'b0; n_od0_rw = 1'b0; n_od1_rw = 1'b0;
    n_ev0_op = '0; n_ev1_op = '0; n_od0_op = '0; n_od1_op = '0;
    n_ev0_f3 = '0; n_ev1_f3 = '0; n_od0_f3 = '0; n_od1_f3 = '0;
    n_ev0_f7 = '0; n_ev1_f7 = '0;
    n_ev0_prd = '0; n_ev1_prd = '0; n_od0_prd = '0; n_od1_prd = '0;
    n_ev0_imm = '0; n_ev1_imm = '0; n_od0_imm = '0; n_od1_imm = '0;
    n_ev0_pc  = '0; n_ev1_pc  = '0; n_od0_pc  = '0; n_od1_pc  = '0;
    n_ev0_rs1 = '0; n_ev1_rs1 = '0; n_od0_rs1 = '0; n_od1_rs1 = '0;
    n_ev0_rs2 = '0; n_ev1_rs2 = '0; n_od0_rs2 = '0; n_od1_rs2 = '0;

    if (i0_port == 3'd0) begin
      n_ev0_en = 1'b1; n_ev0_rw = i0_reg_write_iss;
      n_ev0_op = i0_opcode_iss; n_ev0_f3 = i0_funct3_iss; n_ev0_f7 = i0_funct7_iss;
      n_ev0_prd = i0_prd_iss;
      n_ev0_imm = i0_imm_iss; n_ev0_pc = i0_pc_iss;
      n_ev0_rs1 = i0_rs1_data; n_ev0_rs2 = i0_rs2_data;
    end else if (i0_port == 3'd1) begin
      n_ev1_en = 1'b1; n_ev1_rw = i0_reg_write_iss;
      n_ev1_op = i0_opcode_iss; n_ev1_f3 = i0_funct3_iss; n_ev1_f7 = i0_funct7_iss;
      n_ev1_prd = i0_prd_iss;
      n_ev1_imm = i0_imm_iss; n_ev1_pc = i0_pc_iss;
      n_ev1_rs1 = i0_rs1_data; n_ev1_rs2 = i0_rs2_data;
    end else if (i0_port == 3'd2) begin
      n_od0_en = 1'b1; n_od0_rw = i0_reg_write_iss;
      n_od0_op = i0_opcode_iss; n_od0_f3 = i0_funct3_iss;
      n_od0_prd = i0_prd_iss;
      n_od0_imm = i0_imm_iss; n_od0_pc = i0_pc_iss;
      n_od0_rs1 = i0_rs1_data; n_od0_rs2 = i0_rs2_data;
    end else if (i0_port == 3'd3) begin
      n_od1_en = 1'b1; n_od1_rw = i0_reg_write_iss;
      n_od1_op = i0_opcode_iss; n_od1_f3 = i0_funct3_iss;
      n_od1_prd = i0_prd_iss;
      n_od1_imm = i0_imm_iss; n_od1_pc = i0_pc_iss;
      n_od1_rs1 = i0_rs1_data; n_od1_rs2 = i0_rs2_data;
    end

    if (i1_port == 3'd0) begin
      n_ev0_en = 1'b1; n_ev0_rw = i1_reg_write_iss;
      n_ev0_op = i1_opcode_iss; n_ev0_f3 = i1_funct3_iss; n_ev0_f7 = i1_funct7_iss;
      n_ev0_prd = i1_prd_iss;
      n_ev0_imm = i1_imm_iss; n_ev0_pc = i1_pc_iss;
      n_ev0_rs1 = i1_rs1_data; n_ev0_rs2 = i1_rs2_data;
    end else if (i1_port == 3'd1) begin
      n_ev1_en = 1'b1; n_ev1_rw = i1_reg_write_iss;
      n_ev1_op = i1_opcode_iss; n_ev1_f3 = i1_funct3_iss; n_ev1_f7 = i1_funct7_iss;
      n_ev1_prd = i1_prd_iss;
      n_ev1_imm = i1_imm_iss; n_ev1_pc = i1_pc_iss;
      n_ev1_rs1 = i1_rs1_data; n_ev1_rs2 = i1_rs2_data;
    end else if (i1_port == 3'd2) begin
      n_od0_en = 1'b1; n_od0_rw = i1_reg_write_iss;
      n_od0_op = i1_opcode_iss; n_od0_f3 = i1_funct3_iss;
      n_od0_prd = i1_prd_iss;
      n_od0_imm = i1_imm_iss; n_od0_pc = i1_pc_iss;
      n_od0_rs1 = i1_rs1_data; n_od0_rs2 = i1_rs2_data;
    end else if (i1_port == 3'd3) begin
      n_od1_en = 1'b1; n_od1_rw = i1_reg_write_iss;
      n_od1_op = i1_opcode_iss; n_od1_f3 = i1_funct3_iss;
      n_od1_prd = i1_prd_iss;
      n_od1_imm = i1_imm_iss; n_od1_pc = i1_pc_iss;
      n_od1_rs1 = i1_rs1_data; n_od1_rs2 = i1_rs2_data;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      ev0_enable_ex <= 1'b0; ev0_reg_write_ex <= 1'b0;
      ev0_opcode_ex <= '0; ev0_funct3_ex <= '0; ev0_funct7_ex <= '0;
      ev0_prd_ex <= '0; ev0_imm_ex <= '0; ev0_pc_ex <= '0;
      ev0_rs1_data_ex <= '0; ev0_rs2_data_ex <= '0;

      ev1_enable_ex <= 1'b0; ev1_reg_write_ex <= 1'b0;
      ev1_opcode_ex <= '0; ev1_funct3_ex <= '0; ev1_funct7_ex <= '0;
      ev1_prd_ex <= '0; ev1_imm_ex <= '0; ev1_pc_ex <= '0;
      ev1_rs1_data_ex <= '0; ev1_rs2_data_ex <= '0;

      od0_enable_ex <= 1'b0; od0_reg_write_ex <= 1'b0;
      od0_opcode_ex <= '0; od0_funct3_ex <= '0;
      od0_prd_ex <= '0; od0_imm_ex <= '0; od0_pc_ex <= '0;
      od0_rs1_data_ex <= '0; od0_rs2_data_ex <= '0;

      od1_enable_ex <= 1'b0; od1_reg_write_ex <= 1'b0;
      od1_opcode_ex <= '0; od1_funct3_ex <= '0;
      od1_prd_ex <= '0; od1_imm_ex <= '0; od1_pc_ex <= '0;
      od1_rs1_data_ex <= '0; od1_rs2_data_ex <= '0;
    end else if (enable && !stall) begin
      ev0_enable_ex <= n_ev0_en; ev0_reg_write_ex <= n_ev0_rw;
      ev0_opcode_ex <= n_ev0_op; ev0_funct3_ex <= n_ev0_f3; ev0_funct7_ex <= n_ev0_f7;
      ev0_prd_ex <= n_ev0_prd; ev0_imm_ex <= n_ev0_imm; ev0_pc_ex <= n_ev0_pc;
      ev0_rs1_data_ex <= n_ev0_rs1; ev0_rs2_data_ex <= n_ev0_rs2;

      ev1_enable_ex <= n_ev1_en; ev1_reg_write_ex <= n_ev1_rw;
      ev1_opcode_ex <= n_ev1_op; ev1_funct3_ex <= n_ev1_f3; ev1_funct7_ex <= n_ev1_f7;
      ev1_prd_ex <= n_ev1_prd; ev1_imm_ex <= n_ev1_imm; ev1_pc_ex <= n_ev1_pc;
      ev1_rs1_data_ex <= n_ev1_rs1; ev1_rs2_data_ex <= n_ev1_rs2;

      od0_enable_ex <= n_od0_en; od0_reg_write_ex <= n_od0_rw;
      od0_opcode_ex <= n_od0_op; od0_funct3_ex <= n_od0_f3;
      od0_prd_ex <= n_od0_prd; od0_imm_ex <= n_od0_imm; od0_pc_ex <= n_od0_pc;
      od0_rs1_data_ex <= n_od0_rs1; od0_rs2_data_ex <= n_od0_rs2;

      od1_enable_ex <= n_od1_en; od1_reg_write_ex <= n_od1_rw;
      od1_opcode_ex <= n_od1_op; od1_funct3_ex <= n_od1_f3;
      od1_prd_ex <= n_od1_prd; od1_imm_ex <= n_od1_imm; od1_pc_ex <= n_od1_pc;
      od1_rs1_data_ex <= n_od1_rs1; od1_rs2_data_ex <= n_od1_rs2;
    end
  end

endmodule
