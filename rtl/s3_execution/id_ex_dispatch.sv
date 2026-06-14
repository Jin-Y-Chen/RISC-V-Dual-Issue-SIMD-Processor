`timescale 1ns / 1ps

// ID/EX dispatch — pipeline register into the S3 lanes (project_outline "Dispatch").
// Takes all S2 (decode) outputs for the fetch pair I0 (older) / I1 (younger).
//
// Port-based EX: each lane has two copies (ev0/ev1, od0/od1), so an
// even/even or odd/odd pair dual-issues with no structural hazard. Fixed slot
// mapping: I0 -> *0 ports, I1 -> *1 ports. No stall: RAW dependences are
// resolved by same-cycle forwarding in EX (forward_unit), not by blocking I1.
module id_ex_dispatch
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  //input logic stall_od0,
  //input logic stall_od1, 
  //input logic stall_ev0,
  //input logic stall_ev1,

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

  // --- Per-slot writeback control (EX, registered; independent of lane_sel) ---
  // One reg_write + pc per instruction slot; instruction order/age is
  // determined by pc downstream (slot 0 = I0 = older), not by lane.
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output logic [31:0] i0_pc_ex,
  output logic [31:0] i1_pc_ex,

  // --- Even lane pair (EX, registered): ALU OP / OP-IMM ---
  output logic        ev0_enable_ex,
  output logic [6:0]  ev0_opcode_ex,
  output logic [2:0]  ev0_funct3_ex,
  output logic [6:0]  ev0_funct7_ex,
  output logic [4:0]  ev0_rd_ex,
  output logic [4:0]  ev0_rs1_addr_ex,
  output logic [4:0]  ev0_rs2_addr_ex,
  output logic [31:0] ev0_imm_ex,
  output logic [31:0] ev0_rs1_data_ex,
  output logic [31:0] ev0_rs2_data_ex,
  output logic [31:0] ev0_pc_ex,

  output logic        ev1_enable_ex,
  output logic [6:0]  ev1_opcode_ex,
  output logic [2:0]  ev1_funct3_ex,
  output logic [6:0]  ev1_funct7_ex,
  output logic [4:0]  ev1_rd_ex,
  output logic [4:0]  ev1_rs1_addr_ex,
  output logic [4:0]  ev1_rs2_addr_ex,
  output logic [31:0] ev1_imm_ex,
  output logic [31:0] ev1_rs1_data_ex,
  output logic [31:0] ev1_rs2_data_ex,
  output logic [31:0] ev1_pc_ex,

  // --- Odd lane pair (EX, registered): LOAD/STORE, BRANCH, JAL/JALR, LUI/AUIPC ---
  output logic        od0_enable_ex,
  output logic [6:0]  od0_opcode_ex,
  output logic [2:0]  od0_funct3_ex,
  output logic [4:0]  od0_rd_ex,
  output logic [4:0]  od0_rs1_addr_ex,
  output logic [4:0]  od0_rs2_addr_ex,
  output logic [31:0] od0_imm_ex,
  output logic [31:0] od0_rs1_data_ex,
  output logic [31:0] od0_rs2_data_ex,
  output logic [31:0] od0_pc_ex,

  output logic        od1_enable_ex,
  output logic [6:0]  od1_opcode_ex,
  output logic [2:0]  od1_funct3_ex,
  output logic [4:0]  od1_rd_ex,
  output logic [4:0]  od1_rs1_addr_ex,
  output logic [4:0]  od1_rs2_addr_ex,
  output logic [31:0] od1_imm_ex,
  output logic [31:0] od1_rs1_data_ex,
  output logic [31:0] od1_rs2_data_ex,
  output logic [31:0] od1_pc_ex
);

  // ---------------------------------------------------------------------
  // Lane routing: fixed slot mapping, no muxes.
  // I0 -> slot-0 copy of its lane, I1 -> slot-1 copy of its lane.
  // ---------------------------------------------------------------------
  logic ev0_enable_next;
  logic od0_enable_next;
  logic ev1_enable_next;
  logic od1_enable_next;

  assign ev0_enable_next = i0_valid_id && (i0_lane_sel_id == LANE_EVEN);
  assign ev1_enable_next = i1_valid_id && (i1_lane_sel_id == LANE_EVEN);
  assign od1_enable_next = i1_valid_id && (i1_lane_sel_id == LANE_ODD);

  // ---------------------------------------------------------------------
  // Dual-issue memory port arbitration (same eff. byte addr at ID)
  // RAR: lw + lw  -> I1 read only (clear od0_enable)
  // WAW: sw + sw  -> I1 write only (clear od0_enable)
  // ---------------------------------------------------------------------
  logic        i0_load_id;
  logic        i0_store_id;
  logic        i1_load_id;
  logic        i1_store_id;
  logic [31:0] i0_eff_addr_id;
  logic [31:0] i1_eff_addr_id;
  logic        mem_same_addr_id;
  logic        suppress_od0_mem_port;

  assign i0_load_id  = i0_valid_id && (i0_lane_sel_id == LANE_ODD) && (i0_opcode_id == OPC_LOAD);
  assign i0_store_id = i0_valid_id && (i0_lane_sel_id == LANE_ODD) && (i0_opcode_id == OPC_STORE);
  assign i1_load_id  = i1_valid_id && (i1_lane_sel_id == LANE_ODD) && (i1_opcode_id == OPC_LOAD);
  assign i1_store_id = i1_valid_id && (i1_lane_sel_id == LANE_ODD) && (i1_opcode_id == OPC_STORE);

  assign i0_eff_addr_id = i0_rs1_data_id + i0_imm_id;
  assign i1_eff_addr_id = i1_rs1_data_id + i1_imm_id;
  assign mem_same_addr_id = (i0_eff_addr_id == i1_eff_addr_id);

  assign suppress_od0_mem_port = mem_same_addr_id &&
                                 ((i0_load_id && i1_load_id) || (i0_store_id && i1_store_id));

  assign od0_enable_next = i0_valid_id && (i0_lane_sel_id == LANE_ODD) && !suppress_od0_mem_port;

  // ---------------------------------------------------------------------
  // ID/EX pipeline register
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      i0_reg_write_ex <= 1'b0;
      i1_reg_write_ex <= 1'b0;
      i0_pc_ex        <= 32'd0;
      i1_pc_ex        <= 32'd0;

      ev0_enable_ex   <= 1'b0;
      ev0_opcode_ex   <= 7'd0;
      ev0_funct3_ex   <= 3'd0;
      ev0_funct7_ex   <= 7'd0;
      ev0_rd_ex       <= 5'd0;
      ev0_rs1_addr_ex <= 5'd0;
      ev0_rs2_addr_ex <= 5'd0;
      ev0_imm_ex      <= 32'd0;
      ev0_rs1_data_ex <= 32'd0;
      ev0_rs2_data_ex <= 32'd0;
      ev0_pc_ex       <= 32'd0;

      ev1_enable_ex   <= 1'b0;
      ev1_opcode_ex   <= 7'd0;
      ev1_funct3_ex   <= 3'd0;
      ev1_funct7_ex   <= 7'd0;
      ev1_rd_ex       <= 5'd0;
      ev1_rs1_addr_ex <= 5'd0;
      ev1_rs2_addr_ex <= 5'd0;
      ev1_imm_ex      <= 32'd0;
      ev1_rs1_data_ex <= 32'd0;
      ev1_rs2_data_ex <= 32'd0;
      ev1_pc_ex       <= 32'd0;

      od0_enable_ex   <= 1'b0;
      od0_opcode_ex   <= 7'd0;
      od0_funct3_ex   <= 3'd0;
      od0_rd_ex       <= 5'd0;
      od0_rs1_addr_ex <= 5'd0;
      od0_rs2_addr_ex <= 5'd0;
      od0_imm_ex      <= 32'd0;
      od0_rs1_data_ex <= 32'd0;
      od0_rs2_data_ex <= 32'd0;
      od0_pc_ex       <= 32'd0;

      od1_enable_ex   <= 1'b0;
      od1_opcode_ex   <= 7'd0;
      od1_funct3_ex   <= 3'd0;
      od1_rd_ex       <= 5'd0;
      od1_rs1_addr_ex <= 5'd0;
      od1_rs2_addr_ex <= 5'd0;
      od1_imm_ex      <= 32'd0;
      od1_rs1_data_ex <= 32'd0;
      od1_rs2_data_ex <= 32'd0;
      od1_pc_ex       <= 32'd0;
    end else begin
      // Per-slot writeback control (lane-independent)
      i0_reg_write_ex <= i0_valid_id && i0_reg_write_id;
      i1_reg_write_ex <= i1_valid_id && i1_reg_write_id;
      i0_pc_ex        <= i0_pc_id;
      i1_pc_ex        <= i1_pc_id;

      // Slot 0 <- I0 (older)
      ev0_enable_ex   <= ev0_enable_next;
      ev0_opcode_ex   <= i0_opcode_id;
      ev0_funct3_ex   <= i0_funct3_id;
      ev0_funct7_ex   <= i0_funct7_id;
      ev0_rd_ex       <= i0_rd_addr_id;
      ev0_rs1_addr_ex <= i0_rs1_addr_id;
      ev0_rs2_addr_ex <= i0_rs2_addr_id;
      ev0_imm_ex      <= i0_imm_id;
      ev0_rs1_data_ex <= i0_rs1_data_id;
      ev0_rs2_data_ex <= i0_rs2_data_id;
      ev0_pc_ex       <= i0_pc_id;

      od0_enable_ex   <= od0_enable_next;
      od0_opcode_ex   <= i0_opcode_id;
      od0_funct3_ex   <= i0_funct3_id;
      od0_rd_ex       <= i0_rd_addr_id;
      od0_rs1_addr_ex <= i0_rs1_addr_id;
      od0_rs2_addr_ex <= i0_rs2_addr_id;
      od0_imm_ex      <= i0_imm_id;
      od0_rs1_data_ex <= i0_rs1_data_id;
      od0_rs2_data_ex <= i0_rs2_data_id;
      od0_pc_ex       <= i0_pc_id;

      // Slot 1 <- I1 (younger)
      ev1_enable_ex   <= ev1_enable_next;
      ev1_opcode_ex   <= i1_opcode_id;
      ev1_funct3_ex   <= i1_funct3_id;
      ev1_funct7_ex   <= i1_funct7_id;
      ev1_rd_ex       <= i1_rd_addr_id;
      ev1_rs1_addr_ex <= i1_rs1_addr_id;
      ev1_rs2_addr_ex <= i1_rs2_addr_id;
      ev1_imm_ex      <= i1_imm_id;
      ev1_rs1_data_ex <= i1_rs1_data_id;
      ev1_rs2_data_ex <= i1_rs2_data_id;
      ev1_pc_ex       <= i1_pc_id;

      od1_enable_ex   <= od1_enable_next;
      od1_opcode_ex   <= i1_opcode_id;
      od1_funct3_ex   <= i1_funct3_id;
      od1_rd_ex       <= i1_rd_addr_id;
      od1_rs1_addr_ex <= i1_rs1_addr_id;
      od1_rs2_addr_ex <= i1_rs2_addr_id;
      od1_imm_ex      <= i1_imm_id;
      od1_rs1_data_ex <= i1_rs1_data_id;
      od1_rs2_data_ex <= i1_rs2_data_id;
      od1_pc_ex       <= i1_pc_id;
    end
  end

endmodule
