`timescale 1ns / 1ps

// ID/EX dispatch — pipeline register into the S3 lanes (project_outline "Dispatch").
// Takes all S2 (decode) outputs for the fetch pair I0 (older) / I1 (younger).
//
// Port-based EX: each lane has two copies (even0/even1, odd0/odd1), so an
// even/even or odd/odd pair dual-issues with no structural hazard. Fixed slot
// mapping: I0 -> *0 ports, I1 -> *1 ports. No stall: RAW dependences are
// resolved by same-cycle forwarding in EX (forward_unit), not by blocking I1.
module id_ex_dispatch
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // --- I0 slot (older insn) from S2: decoder + register file + pc ---
  input  logic        i0_valid_id,
  input  lane_sel_e   i0_lane_sel_id,
  input  logic [6:0]  i0_opcode_id,
  input  logic [2:0]  i0_funct3_id,
  input  logic [6:0]  i0_funct7_id,
  input  logic [4:0]  i0_rd_addr_id,
  input  logic [4:0]  i0_rs1_addr_id,
  input  logic [4:0]  i0_rs2_addr_id,
  input  logic        i0_reg_write_id,
  input  logic [31:0] i0_imm_id,
  input  logic [31:0] i0_rs1_data_id,
  input  logic [31:0] i0_rs2_data_id,
  input  logic [31:0] i0_pc_id,

  // --- I1 slot (younger insn) from S2: decoder + register file + pc ---
  input  logic        i1_valid_id,
  input  lane_sel_e   i1_lane_sel_id,
  input  logic [6:0]  i1_opcode_id,
  input  logic [2:0]  i1_funct3_id,
  input  logic [6:0]  i1_funct7_id,
  input  logic [4:0]  i1_rd_addr_id,
  input  logic [4:0]  i1_rs1_addr_id,
  input  logic [4:0]  i1_rs2_addr_id,
  input  logic        i1_reg_write_id,
  input  logic [31:0] i1_imm_id,
  input  logic [31:0] i1_rs1_data_id,
  input  logic [31:0] i1_rs2_data_id, 
  input  logic [31:0] i1_pc_id,

  // --- Even lane pair (EX, registered): ALU OP / OP-IMM ---
  output logic        even0_en_ex,
  output logic [6:0]  even0_opcode_ex,
  output logic [2:0]  even0_funct3_ex,
  output logic [6:0]  even0_funct7_ex,
  output logic [4:0]  even0_rd_ex,
  output logic        even0_reg_write_ex,
  output logic [31:0] even0_imm_ex,
  output logic [31:0] even0_rs1_data_ex,
  output logic [31:0] even0_rs2_data_ex,
  output logic [31:0] even0_pc_ex,

  output logic        even1_en_ex,
  output logic [6:0]  even1_opcode_ex,
  output logic [2:0]  even1_funct3_ex,
  output logic [6:0]  even1_funct7_ex,
  output logic [4:0]  even1_rd_ex,
  output logic        even1_reg_write_ex,
  output logic [31:0] even1_imm_ex,
  output logic [31:0] even1_rs1_data_ex,
  output logic [31:0] even1_rs2_data_ex,
  output logic [31:0] even1_pc_ex,

  // --- Odd lane pair (EX, registered): LOAD/STORE, BRANCH, JAL/JALR, LUI/AUIPC ---
  output logic        odd0_en_ex,
  output logic [6:0]  odd0_opcode_ex,
  output logic [2:0]  odd0_funct3_ex,
  output logic [4:0]  odd0_rd_ex,
  output logic        odd0_reg_write_ex,
  output logic [31:0] odd0_imm_ex,
  output logic [31:0] odd0_rs1_data_ex,
  output logic [31:0] odd0_rs2_data_ex,
  output logic [31:0] odd0_pc_ex,

  output logic        odd1_en_ex,
  output logic [6:0]  odd1_opcode_ex,
  output logic [2:0]  odd1_funct3_ex,
  output logic [4:0]  odd1_rd_ex,
  output logic        odd1_reg_write_ex,
  output logic [31:0] odd1_imm_ex,
  output logic [31:0] odd1_rs1_data_ex,
  output logic [31:0] odd1_rs2_data_ex,
  output logic [31:0] odd1_pc_ex
);

  // ---------------------------------------------------------------------
  // Lane routing: fixed slot mapping, no muxes.
  // I0 -> slot-0 copy of its lane, I1 -> slot-1 copy of its lane.
  // ---------------------------------------------------------------------
  logic even0_en_next;
  logic odd0_en_next;
  logic even1_en_next;
  logic odd1_en_next;

  assign even0_en_next = i0_valid_id && (i0_lane_sel_id == LANE_EVEN);
  assign odd0_en_next  = i0_valid_id && (i0_lane_sel_id == LANE_ODD);
  assign even1_en_next = i1_valid_id && (i1_lane_sel_id == LANE_EVEN);
  assign odd1_en_next  = i1_valid_id && (i1_lane_sel_id == LANE_ODD);

  // ---------------------------------------------------------------------
  // ID/EX pipeline register
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      even0_en_ex        <= 1'b0;
      even0_opcode_ex    <= 7'd0;
      even0_funct3_ex    <= 3'd0;
      even0_funct7_ex    <= 7'd0;
      even0_rd_ex        <= 5'd0;
      even0_reg_write_ex <= 1'b0;
      even0_imm_ex       <= 32'd0;
      even0_rs1_data_ex  <= 32'd0;
      even0_rs2_data_ex  <= 32'd0;
      even0_pc_ex        <= 32'd0;

      even1_en_ex        <= 1'b0;
      even1_opcode_ex    <= 7'd0;
      even1_funct3_ex    <= 3'd0;
      even1_funct7_ex    <= 7'd0;
      even1_rd_ex        <= 5'd0;
      even1_reg_write_ex <= 1'b0;
      even1_imm_ex       <= 32'd0;
      even1_rs1_data_ex  <= 32'd0;
      even1_rs2_data_ex  <= 32'd0;
      even1_pc_ex        <= 32'd0;

      odd0_en_ex         <= 1'b0;
      odd0_opcode_ex     <= 7'd0;
      odd0_funct3_ex     <= 3'd0;
      odd0_rd_ex         <= 5'd0;
      odd0_reg_write_ex  <= 1'b0;
      odd0_imm_ex        <= 32'd0;
      odd0_rs1_data_ex   <= 32'd0;
      odd0_rs2_data_ex   <= 32'd0;
      odd0_pc_ex         <= 32'd0;

      odd1_en_ex         <= 1'b0;
      odd1_opcode_ex     <= 7'd0;
      odd1_funct3_ex     <= 3'd0;
      odd1_rd_ex         <= 5'd0;
      odd1_reg_write_ex  <= 1'b0;
      odd1_imm_ex        <= 32'd0;
      odd1_rs1_data_ex   <= 32'd0;
      odd1_rs2_data_ex   <= 32'd0;
      odd1_pc_ex         <= 32'd0;
    end else begin
      // Slot 0 <- I0 (older)
      even0_en_ex        <= even0_en_next;
      even0_opcode_ex    <= i0_opcode_id;
      even0_funct3_ex    <= i0_funct3_id;
      even0_funct7_ex    <= i0_funct7_id;
      even0_rd_ex        <= i0_rd_addr_id;
      even0_reg_write_ex <= even0_en_next && i0_reg_write_id;
      even0_imm_ex       <= i0_imm_id;
      even0_rs1_data_ex  <= i0_rs1_data_id;
      even0_rs2_data_ex  <= i0_rs2_data_id;
      even0_pc_ex        <= i0_pc_id;

      odd0_en_ex         <= odd0_en_next;
      odd0_opcode_ex     <= i0_opcode_id;
      odd0_funct3_ex     <= i0_funct3_id;
      odd0_rd_ex         <= i0_rd_addr_id;
      odd0_reg_write_ex  <= odd0_en_next && i0_reg_write_id;
      odd0_imm_ex        <= i0_imm_id;
      odd0_rs1_data_ex   <= i0_rs1_data_id;
      odd0_rs2_data_ex   <= i0_rs2_data_id;
      odd0_pc_ex         <= i0_pc_id;

      // Slot 1 <- I1 (younger)
      even1_en_ex        <= even1_en_next;
      even1_opcode_ex    <= i1_opcode_id;
      even1_funct3_ex    <= i1_funct3_id;
      even1_funct7_ex    <= i1_funct7_id;
      even1_rd_ex        <= i1_rd_addr_id;
      even1_reg_write_ex <= even1_en_next && i1_reg_write_id;
      even1_imm_ex       <= i1_imm_id;
      even1_rs1_data_ex  <= i1_rs1_data_id;
      even1_rs2_data_ex  <= i1_rs2_data_id;
      even1_pc_ex        <= i1_pc_id;

      odd1_en_ex         <= odd1_en_next;
      odd1_opcode_ex     <= i1_opcode_id;
      odd1_funct3_ex     <= i1_funct3_id;
      odd1_rd_ex         <= i1_rd_addr_id;
      odd1_reg_write_ex  <= odd1_en_next && i1_reg_write_id;
      odd1_imm_ex        <= i1_imm_id;
      odd1_rs1_data_ex   <= i1_rs1_data_id;
      odd1_rs2_data_ex   <= i1_rs2_data_id;
      odd1_pc_ex         <= i1_pc_id;
    end
  end

endmodule
