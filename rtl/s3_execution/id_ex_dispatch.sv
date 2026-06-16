`timescale 1ns / 1ps

// ID/EX dispatch — pipeline register into the S3 lanes (project_outline "Dispatch").
// Integrates in-order scoreboard: same-bundle RAW single-issues I0 and buffers I1.
//
// GPR WAW (I0 rd == I1 rd): not checked at dispatch. Both insns issue when allowed;
// side effects (JAL/JALR PC, branches, memory) must run even when rd matches.
// Same-rd WB is merged in register_file (younger wpc wins). Memory same-word WAW/RAR
// port arbitration (suppress_od0_mem_port) is separate — eff. addr, not rd.
// Port-based EX: I0 -> *0 ports, I1 -> *1 ports. Operand bypass at EX is forward_unit;
// issue gating and buffered replay are scoreboard + 4-entry insn_buffer here.
module id_ex_dispatch
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        stall_mem,

  // --- I0 slot (older insn) from S2: decoder + register file + pc ---
  input  logic        i0_valid_id,
  input  lane_sel_e   i0_lane_sel_id,
  input  logic [6:0]  i0_opcode_id,
  input  logic [2:0]  i0_funct3_id,
  input  logic [6:0]  i0_funct7_id,
  input  logic [4:0]  i0_rd_addr_id,
  input  logic [4:0]  i0_rs1_addr_id,
  input  logic [4:0]  i0_rs2_addr_id,
  input  logic        i0_rs1_use_id,
  input  logic        i0_rs2_use_id,
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
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  logic        i1_reg_write_id,
  input  logic [31:0] i1_imm_id,
  input  logic [31:0] i1_rs1_data_id,
  input  logic [31:0] i1_rs2_data_id,
  input  logic [31:0] i1_pc_id,

  // Forward + WB retire (scoreboard operand-ready / busy clear)
  input  logic        mem0_reg_write,
  input  logic [4:0]  mem0_rd,
  input  logic        mem1_reg_write,
  input  logic [4:0]  mem1_rd,
  input  logic        wb0_reg_write,
  input  logic [4:0]  wb0_rd,
  input  logic        wb1_reg_write,
  input  logic [4:0]  wb1_rd,

  output logic        stall_id,
  output logic        i1_hold_active,
  output logic        bundle_raw,

  // --- Per-slot writeback control (EX, registered) ---
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output logic [31:0] i0_pc_ex,
  output logic [31:0] i1_pc_ex,

  // --- Even lane pair (EX, registered) ---
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

  // --- Odd lane pair (EX, registered) ---
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
  // insn_buffer — up to 4 suppressed instructions (FIFO, in-order replay)
  // ---------------------------------------------------------------------
  logic        buf_empty;
  logic        buf_push_ok;
  logic        buf_full_unused;
  logic [2:0]  buf_count;
  logic        buf_push;
  logic        buf_pop;

  lane_sel_e   buf_head_lane;
  logic [6:0]  buf_head_opcode;
  logic [2:0]  buf_head_funct3;
  logic [6:0]  buf_head_funct7;
  logic [4:0]  buf_head_rd;
  logic [4:0]  buf_head_rs1;
  logic [4:0]  buf_head_rs2;
  logic        buf_head_rs1_use;
  logic        buf_head_rs2_use;
  logic        buf_head_reg_write;
  logic [31:0] buf_head_imm;
  logic [31:0] buf_head_rs1_data;
  logic [31:0] buf_head_rs2_data;
  logic [31:0] buf_head_pc;
  logic [4:0]  buf_head_producer_rd;
  logic        buf_head_producer_valid;
  logic [31:0] buf_head_bundle_i0_pc;
  logic [31:0] buf_head_bundle_i1_pc;

  assign i1_hold_active = !buf_empty;

  // ---------------------------------------------------------------------
  // Scoreboard — issue gate
  // ---------------------------------------------------------------------
  logic issue_i0;
  logic issue_i1;
  logic set_i1_hold;
  logic issue_i1_from_hold;

  logic [31:0] held_bundle_i0_pc_q;
  logic [31:0] held_bundle_i1_pc_q;
  logic        suppress_bundle_raw_q;

  wire suppress_bundle_raw_eff =
      suppress_bundle_raw_q &&
      (i0_pc_id == held_bundle_i0_pc_q) &&
      (i1_pc_id == held_bundle_i1_pc_q);

  logic        i1_valid_act;
  lane_sel_e   i1_lane_sel_act;
  logic [6:0]  i1_opcode_act;
  logic [2:0]  i1_funct3_act;
  logic [6:0]  i1_funct7_act;
  logic [4:0]  i1_rd_act;
  logic [4:0]  i1_rs1_addr_act;
  logic [4:0]  i1_rs2_addr_act;
  logic        i1_reg_write_act;
  logic [31:0] i1_imm_act;
  logic [31:0] i1_rs1_data_act;
  logic [31:0] i1_rs2_data_act;
  logic [31:0] i1_pc_act;

  logic issue_i0_eff;
  logic issue_i1_eff;

  assign issue_i0_eff = issue_i0 && i0_valid_id && (i0_lane_sel_id != LANE_NONE);
  assign issue_i1_eff = issue_i1 && i1_valid_act && (i1_lane_sel_act != LANE_NONE);

  scoreboard u_scoreboard (
    .i0_valid           (i0_valid_id),
    .i0_reg_write       (i0_reg_write_id),
    .i0_rs1_use         (i0_rs1_use_id),
    .i0_rs2_use         (i0_rs2_use_id),
    .i0_rd              (i0_rd_addr_id),
    .i0_rs1             (i0_rs1_addr_id),
    .i0_rs2             (i0_rs2_addr_id),

    .i1_valid           (i1_valid_id),
    .i1_reg_write       (i1_reg_write_id),
    .i1_rs1_use         (i1_rs1_use_id),
    .i1_rs2_use         (i1_rs2_use_id),
    .i1_rd              (i1_rd_addr_id),
    .i1_rs1             (i1_rs1_addr_id),
    .i1_rs2             (i1_rs2_addr_id),
    .buf_empty              (buf_empty),
    .buf_push_ok            (buf_push_ok),
    .buf_head_rs1_use       (buf_head_rs1_use),
    .buf_head_rs2_use       (buf_head_rs2_use),
    .buf_head_rs1           (buf_head_rs1),
    .buf_head_rs2           (buf_head_rs2),
    .buf_head_producer_valid(buf_head_producer_valid),
    .buf_head_producer_rd   (buf_head_producer_rd),
    .mem0_reg_write         (mem0_reg_write),
    .mem0_rd            (mem0_rd),
    .mem1_reg_write     (mem1_reg_write),
    .mem1_rd            (mem1_rd),
    .wb0_reg_write      (wb0_reg_write),
    .wb0_rd             (wb0_rd),
    .wb1_reg_write      (wb1_reg_write),
    .wb1_rd             (wb1_rd),
    .stall_mem          (stall_mem),

    .suppress_bundle_raw(suppress_bundle_raw_eff),
    .hold_replay_block  (set_i1_hold),
    .issue_i0           (issue_i0),
    .issue_i1           (issue_i1),
    .stall_id           (stall_id),
    .set_i1_hold        (set_i1_hold),
    .issue_i1_from_hold (issue_i1_from_hold),
    .bundle_raw         (bundle_raw)
  );

  assign buf_push = set_i1_hold;
  assign buf_pop  = issue_i1_from_hold;

  insn_buffer #(
    .DEPTH(4)
  ) u_insn_buffer (
    .clk                  (clk),
    .rst_n                (rst_n),
    .flush                (flush),
    .push                 (buf_push),
    .pop                  (buf_pop),
    .push_lane_sel        (i1_lane_sel_id),
    .push_opcode          (i1_opcode_id),
    .push_funct3          (i1_funct3_id),
    .push_funct7          (i1_funct7_id),
    .push_rd              (i1_rd_addr_id),
    .push_rs1             (i1_rs1_addr_id),
    .push_rs2             (i1_rs2_addr_id),
    .push_rs1_use         (i1_rs1_use_id),
    .push_rs2_use         (i1_rs2_use_id),
    .push_reg_write       (i1_reg_write_id),
    .push_imm             (i1_imm_id),
    .push_rs1_data        (i1_rs1_data_id),
    .push_rs2_data        (i1_rs2_data_id),
    .push_pc              (i1_pc_id),
    .push_producer_rd     (i0_rd_addr_id),
    .push_producer_valid  (1'b1),
    .push_bundle_i0_pc    (i0_pc_id),
    .push_bundle_i1_pc    (i1_pc_id),
    .empty                (buf_empty),
    .full                 (buf_full_unused),
    .count                (buf_count),
    .push_ok              (buf_push_ok),
    .head_lane_sel        (buf_head_lane),
    .head_opcode          (buf_head_opcode),
    .head_funct3          (buf_head_funct3),
    .head_funct7          (buf_head_funct7),
    .head_rd              (buf_head_rd),
    .head_rs1             (buf_head_rs1),
    .head_rs2             (buf_head_rs2),
    .head_rs1_use         (buf_head_rs1_use),
    .head_rs2_use         (buf_head_rs2_use),
    .head_reg_write       (buf_head_reg_write),
    .head_imm             (buf_head_imm),
    .head_rs1_data        (buf_head_rs1_data),
    .head_rs2_data        (buf_head_rs2_data),
    .head_pc              (buf_head_pc),
    .head_producer_rd     (buf_head_producer_rd),
    .head_producer_valid  (buf_head_producer_valid),
    .head_bundle_i0_pc    (buf_head_bundle_i0_pc),
    .head_bundle_i1_pc    (buf_head_bundle_i1_pc)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      held_bundle_i0_pc_q   <= 32'd0;
      held_bundle_i1_pc_q   <= 32'd0;
      suppress_bundle_raw_q <= 1'b0;
    end else if (issue_i1_from_hold) begin
      held_bundle_i0_pc_q   <= buf_head_bundle_i0_pc;
      held_bundle_i1_pc_q   <= buf_head_bundle_i1_pc;
      suppress_bundle_raw_q <= 1'b1;
    end else if (suppress_bundle_raw_q &&
                 ((i0_pc_id != held_bundle_i0_pc_q) ||
                  (i1_pc_id != held_bundle_i1_pc_q))) begin
      suppress_bundle_raw_q <= 1'b0;
    end
  end

  // ---------------------------------------------------------------------
  // Active I1 bundle mux (ID vs buffer head replay)
  // ---------------------------------------------------------------------
  always_comb begin
    if (issue_i1_from_hold) begin
      i1_valid_act      = 1'b1;
      i1_lane_sel_act   = buf_head_lane;
      i1_opcode_act     = buf_head_opcode;
      i1_funct3_act     = buf_head_funct3;
      i1_funct7_act     = buf_head_funct7;
      i1_rd_act         = buf_head_rd;
      i1_rs1_addr_act   = buf_head_rs1;
      i1_rs2_addr_act   = buf_head_rs2;
      i1_reg_write_act  = buf_head_reg_write;
      i1_imm_act        = buf_head_imm;
      i1_rs1_data_act   = buf_head_rs1_data;
      i1_rs2_data_act   = buf_head_rs2_data;
      i1_pc_act         = buf_head_pc;
    end else begin
      i1_valid_act      = i1_valid_id;
      i1_lane_sel_act   = i1_lane_sel_id;
      i1_opcode_act     = i1_opcode_id;
      i1_funct3_act     = i1_funct3_id;
      i1_funct7_act     = i1_funct7_id;
      i1_rd_act         = i1_rd_addr_id;
      i1_rs1_addr_act   = i1_rs1_addr_id;
      i1_rs2_addr_act   = i1_rs2_addr_id;
      i1_reg_write_act  = i1_reg_write_id;
      i1_imm_act        = i1_imm_id;
      i1_rs1_data_act   = i1_rs1_data_id;
      i1_rs2_data_act   = i1_rs2_data_id;
      i1_pc_act         = i1_pc_id;
    end
  end

  // ---------------------------------------------------------------------
  // Lane routing (after issue gate)
  // ---------------------------------------------------------------------
  logic ev0_enable_next;
  logic od0_enable_next;
  logic ev1_enable_next;
  logic od1_enable_next;

  assign ev0_enable_next = issue_i0_eff && (i0_lane_sel_id == LANE_EVEN);
  assign ev1_enable_next = issue_i1_eff && (i1_lane_sel_act == LANE_EVEN);
  assign od1_enable_next = issue_i1_eff && (i1_lane_sel_act == LANE_ODD);

  // Dual-issue memory port arbitration (same eff. byte addr at ID)
  logic        i0_load_id;
  logic        i0_store_id;
  logic        i1_load_act;
  logic        i1_store_act;
  logic [31:0] i0_eff_addr_id;
  logic [31:0] i1_eff_addr_act;
  logic        mem_same_addr_id;
  logic        suppress_od0_mem_port;

  assign i0_load_id  = issue_i0_eff && (i0_lane_sel_id == LANE_ODD) &&
                       (i0_opcode_id == OPC_LOAD);
  assign i0_store_id = issue_i0_eff && (i0_lane_sel_id == LANE_ODD) &&
                       (i0_opcode_id == OPC_STORE);
  assign i1_load_act = issue_i1_eff && (i1_lane_sel_act == LANE_ODD) &&
                       (i1_opcode_act == OPC_LOAD);
  assign i1_store_act = issue_i1_eff && (i1_lane_sel_act == LANE_ODD) &&
                        (i1_opcode_act == OPC_STORE);

  assign i0_eff_addr_id  = i0_rs1_data_id + i0_imm_id;
  assign i1_eff_addr_act = i1_rs1_data_act + i1_imm_act;
  assign mem_same_addr_id = (i0_eff_addr_id == i1_eff_addr_act);

  assign suppress_od0_mem_port = mem_same_addr_id &&
                                 ((i0_load_id && i1_load_act) ||
                                  (i0_store_id && i1_store_act));

  assign od0_enable_next = issue_i0_eff && (i0_lane_sel_id == LANE_ODD) &&
                           !suppress_od0_mem_port;

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
    end else if (stall_id && !issue_i0_eff && !issue_i1_eff) begin
      // Full pipeline stall — hold EX register contents
    end else begin
      if (issue_i0_eff) begin
        i0_reg_write_ex <= i0_valid_id && i0_reg_write_id &&
                           (ev0_enable_next || od0_enable_next);
        i0_pc_ex        <= i0_pc_id;

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
      end else begin
        i0_reg_write_ex <= 1'b0;
        i0_pc_ex        <= 32'd0;
        ev0_enable_ex   <= 1'b0;
        od0_enable_ex   <= 1'b0;
      end

      if (issue_i1_eff) begin
        i1_reg_write_ex <= i1_valid_act && i1_reg_write_act &&
                           (ev1_enable_next || od1_enable_next);
        i1_pc_ex        <= i1_pc_act;

        ev1_enable_ex   <= ev1_enable_next;
        ev1_opcode_ex   <= i1_opcode_act;
        ev1_funct3_ex   <= i1_funct3_act;
        ev1_funct7_ex   <= i1_funct7_act;
        ev1_rd_ex       <= i1_rd_act;
        ev1_rs1_addr_ex <= i1_rs1_addr_act;
        ev1_rs2_addr_ex <= i1_rs2_addr_act;
        ev1_imm_ex      <= i1_imm_act;
        ev1_rs1_data_ex <= i1_rs1_data_act;
        ev1_rs2_data_ex <= i1_rs2_data_act;
        ev1_pc_ex       <= i1_pc_act;

        od1_enable_ex   <= od1_enable_next;
        od1_opcode_ex   <= i1_opcode_act;
        od1_funct3_ex   <= i1_funct3_act;
        od1_rd_ex       <= i1_rd_act;
        od1_rs1_addr_ex <= i1_rs1_addr_act;
        od1_rs2_addr_ex <= i1_rs2_addr_act;
        od1_imm_ex      <= i1_imm_act;
        od1_rs1_data_ex <= i1_rs1_data_act;
        od1_rs2_data_ex <= i1_rs2_data_act;
        od1_pc_ex       <= i1_pc_act;
      end else begin
        i1_reg_write_ex <= 1'b0;
        i1_pc_ex        <= 32'd0;
        ev1_enable_ex   <= 1'b0;
        od1_enable_ex   <= 1'b0;
      end
    end
  end

endmodule
