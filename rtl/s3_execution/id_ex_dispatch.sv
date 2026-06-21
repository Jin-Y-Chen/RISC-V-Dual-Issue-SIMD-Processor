`timescale 1ns / 1ps

// ID/EX dispatch — pipeline register into the S3 lanes (project_outline "Dispatch").
// In-order hazards: partial-issue I0, buffer I1 in a single node, full stall until
// stall_remain counts down (1 cycle ALU RAW, 2 cycles load-use), then replay I1.
module id_ex_dispatch
  import rv_dis_pkg::*;
(
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        flush,
  input  logic        i0_valid_id,
  input  lane_sel_e   i0_lane_sel_id,
  input  logic        i0_reg_write_id,
  input  logic        i1_valid_id,
  input  lane_sel_e   i1_lane_sel_id,
  input  logic        i1_rs1_use_id,
  input  logic        i1_rs2_use_id,
  input  logic        i1_reg_write_id,

  // input data
  input  logic [6:0]  i0_opcode_id,
  input  logic [2:0]  i0_funct3_id,
  input  logic [6:0]  i0_funct7_id,
  input  logic [4:0]  i0_rd_addr_id,
  input  logic [4:0]  i0_rs1_addr_id,
  input  logic [4:0]  i0_rs2_addr_id,
  input  logic [31:0] i0_imm_id,
  input  logic [31:0] i0_rs1_data_id,
  input  logic [31:0] i0_rs2_data_id,
  input  logic [31:0] i0_pc_id,
  input  logic [6:0]  i1_opcode_id,
  input  logic [2:0]  i1_funct3_id,
  input  logic [6:0]  i1_funct7_id,
  input  logic [4:0]  i1_rd_addr_id,
  input  logic [4:0]  i1_rs1_addr_id,
  input  logic [4:0]  i1_rs2_addr_id,
  input  logic [31:0] i1_imm_id,
  input  logic [31:0] i1_rs1_data_id,
  input  logic [31:0] i1_rs2_data_id,
  input  logic [31:0] i1_pc_id,

  // output controls
  output logic        stall_id,
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output logic        ev0_enable_ex,
  output logic        ev1_enable_ex,
  output logic        od0_enable_ex,
  output logic        od1_enable_ex,

  // output data
  output logic [31:0] i0_pc_ex,
  output logic [31:0] i1_pc_ex,
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
  output logic [6:0]  od0_opcode_ex,
  output logic [2:0]  od0_funct3_ex,
  output logic [4:0]  od0_rd_ex,
  output logic [4:0]  od0_rs1_addr_ex,
  output logic [4:0]  od0_rs2_addr_ex,
  output logic [31:0] od0_imm_ex,
  output logic [31:0] od0_rs1_data_ex,
  output logic [31:0] od0_rs2_data_ex,
  output logic [31:0] od0_pc_ex,
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
  // I1 buffer node — single entry for in-order hazard replay
  // ---------------------------------------------------------------------
  i1_buffer_node_t buf_q;

  logic [31:0] held_bundle_i0_pc_q;
  logic [31:0] held_bundle_i1_pc_q;
  logic        suppress_bundle_raw_q;

  logic        set_i1_hold;

  wire issue_i1_from_hold =
      buf_q.valid && (buf_q.wait_cnt == 2'd1) && !set_i1_hold;

  // ---------------------------------------------------------------------
  // Scoreboard — issue gate
  // ---------------------------------------------------------------------
  logic        issue_i0;
  logic        issue_i1;
  logic [1:0]  i1_stall_cycles;

  wire suppress_bundle_raw_eff =
      suppress_bundle_raw_q &&
      (i0_pc_id == held_bundle_i0_pc_q) &&
      (i1_pc_id == held_bundle_i1_pc_q);

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

  wire issue_i0_eff = issue_i0 && i0_valid_id && (i0_lane_sel_id != LANE_NONE);
  wire issue_i1_eff = issue_i1 &&
                      (issue_i1_from_hold || i1_valid_id) &&
                      (i1_lane_sel_act != LANE_NONE);

  scoreboard u_scoreboard (
    // internal controls
    .i0_reg_write         (i0_reg_write_id),
    .i1_rs1_use           (i1_rs1_use_id),
    .i1_rs2_use           (i1_rs2_use_id),
    .buf_valid            (buf_q.valid),
    .issue_i1_from_hold   (issue_i1_from_hold),
    .suppress_bundle_raw  (suppress_bundle_raw_eff),
    // input data
    .i0_rd                (i0_rd_addr_id),
    .i0_opcode            (i0_opcode_id),
    .i1_rs1               (i1_rs1_addr_id),
    .i1_rs2               (i1_rs2_addr_id),
    // output controls
    .issue_i0             (issue_i0),
    .issue_i1             (issue_i1),
    .stall_id             (stall_id),
    .set_i1_hold          (set_i1_hold),
    .i1_stall_cycles      (i1_stall_cycles)
  );

  function automatic i1_buffer_node_t pack_i1_from_id;
    input logic [4:0] producer_rd;
    input logic [1:0] stall_cycles;
    pack_i1_from_id.valid        = 1'b1;
    pack_i1_from_id.lane         = i1_lane_sel_id;
    pack_i1_from_id.opcode       = i1_opcode_id;
    pack_i1_from_id.funct3       = i1_funct3_id;
    pack_i1_from_id.funct7       = i1_funct7_id;
    pack_i1_from_id.rd           = i1_rd_addr_id;
    pack_i1_from_id.rs1          = i1_rs1_addr_id;
    pack_i1_from_id.rs2          = i1_rs2_addr_id;
    pack_i1_from_id.rs1_use      = i1_rs1_use_id;
    pack_i1_from_id.rs2_use      = i1_rs2_use_id;
    pack_i1_from_id.reg_write    = i1_reg_write_id;
    pack_i1_from_id.imm          = i1_imm_id;
    pack_i1_from_id.rs1_data     = i1_rs1_data_id;
    pack_i1_from_id.rs2_data     = i1_rs2_data_id;
    pack_i1_from_id.pc           = i1_pc_id;
    pack_i1_from_id.producer_rd  = producer_rd;
    pack_i1_from_id.bundle_i0_pc = i0_pc_id;
    pack_i1_from_id.bundle_i1_pc = i1_pc_id;
    pack_i1_from_id.wait_total   = stall_cycles;
    pack_i1_from_id.wait_cnt     = stall_cycles + 2'd1;  // ALU:2→1, load:3→2→1
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      buf_q.valid               <= 1'b0;
      buf_q.wait_cnt            <= 2'd0;
      held_bundle_i0_pc_q       <= 32'd0;
      held_bundle_i1_pc_q       <= 32'd0;
      suppress_bundle_raw_q      <= 1'b0;
    end else if (!enable) begin
      // Global enable low — hold buffer / replay state
    end else if (issue_i1_from_hold) begin
      buf_q.valid               <= 1'b0;
      buf_q.wait_cnt            <= 2'd0;
      held_bundle_i0_pc_q       <= buf_q.bundle_i0_pc;
      held_bundle_i1_pc_q       <= buf_q.bundle_i1_pc;
      suppress_bundle_raw_q     <= 1'b1;
    end else if (set_i1_hold && i1_valid_id) begin
      buf_q                     <= pack_i1_from_id(i0_rd_addr_id, i1_stall_cycles);
    end else if (buf_q.valid && (buf_q.wait_cnt > 2'd1)) begin
      buf_q.wait_cnt            <= buf_q.wait_cnt - 2'd1;
    end else if (suppress_bundle_raw_q &&
                 ((i0_pc_id != held_bundle_i0_pc_q) ||
                  (i1_pc_id != held_bundle_i1_pc_q))) begin
      suppress_bundle_raw_q     <= 1'b0;
    end
  end

  // Active I1 bundle mux (ID vs buffered replay)
  always_comb begin
    if (issue_i1_from_hold) begin
      i1_lane_sel_act   = buf_q.lane;
      i1_opcode_act     = buf_q.opcode;
      i1_funct3_act     = buf_q.funct3;
      i1_funct7_act     = buf_q.funct7;
      i1_rd_act         = buf_q.rd;
      i1_rs1_addr_act   = buf_q.rs1;
      i1_rs2_addr_act   = buf_q.rs2;
      i1_reg_write_act  = buf_q.reg_write;
      i1_imm_act        = buf_q.imm;
      i1_rs1_data_act   = buf_q.rs1_data;
      i1_rs2_data_act   = buf_q.rs2_data;
      i1_pc_act         = buf_q.pc;
    end else begin
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

  wire ev0_enable_next = issue_i0_eff && (i0_lane_sel_id == LANE_EVEN);
  wire ev1_enable_next = issue_i1_eff && (i1_lane_sel_act == LANE_EVEN);
  wire od0_enable_next = issue_i0_eff && (i0_lane_sel_id == LANE_ODD);
  wire od1_enable_next = issue_i1_eff && (i1_lane_sel_act == LANE_ODD);

  // ID/EX pipeline register — freeze entire EX block while stalling with no issue
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
    end else if (!enable) begin
      // Global enable low — hold all EX lane copies
    end else if (stall_id && !issue_i0_eff && !issue_i1_eff) begin
      // Full stall — hold all lane copies (including after partial I0 issue)
    end else begin
      if (issue_i0_eff) begin
        i0_reg_write_ex <= i0_reg_write_id &&
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
        i1_reg_write_ex <= i1_reg_write_act &&
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
