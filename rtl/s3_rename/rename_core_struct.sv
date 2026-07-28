`timescale 1ns / 1ps

// S3 rename — RAT + ROB (tail alloc). ROB entry owns PRF p32..p63.
// Head commit: ROB retire_en → RRAT / store-buffer; reclaim = ROB head advance.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// Decode payload (lane_sel/opcode/funct/imm/pc) bypasses rename at the top.
import rv_dis_pkg::*;
import rob_pkg::*;

module rename_core_struct (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        stall_rn,
  input  logic        enable,

  input  logic        spec_en_rn      [2],
  input  logic        valid_rn        [2],
  input  logic        reg_write_rn    [2],
  input  logic        store_en_rn     [2],
  input  logic        brch_en_rn      [2],
  input  logic        state_valid_rn  [2],
  input  br_state_t   brch_state_rn   [2],
  input  logic        rs1_use_rn      [2],
  input  logic        rs2_use_rn      [2],
  input  gpr_addr_t   rd_addr_rn      [2],
  input  gpr_addr_t   rs1_addr_rn     [2],
  input  gpr_addr_t   rs2_addr_rn     [2],

  input  logic        wback_en        [2],
  input  prf_addr_t   rob_tag_wb      [2],
  input  logic        brch_taken_wb   [2],

  output logic        stall,

  output logic        valid_rs        [2],
  output logic        spec_en_rs      [2],
  output prf_addr_t   ps1_tag_rs          [2],
  output prf_addr_t   ps2_tag_rs          [2],
  output logic        tag1_valid_rs   [2],
  output logic        tag2_valid_rs   [2],
  output prf_addr_t   rob_tag_rs      [2]
);

  prf_addr_t rob_tag [2];

  logic      rat_alloc_en [2];
  logic      rob_alloc_en [2];
  logic      rob_valid    [2];

  logic      retire_en    [2];
  logic      rrat_en      [2];
  gpr_addr_t rd_addr_cmt  [2];
  prf_addr_t rob_tag_cmt  [2];
  logic      rat_en       [2];
  logic      path_sel     [2];
  logic      stb_en       [2];

  wire go = !flush && !stall_rn && !stall &&
            (valid_rn[0] || valid_rn[1]);

  for (genvar i = 0; i < N_DUAL; i++) begin : g_lane
    assign rob_alloc_en[i] = go && valid_rn[i];
    assign rat_alloc_en[i] = rob_valid[i] && reg_write_rn[i];

    assign valid_rs[i]     = rob_valid[i];
    assign spec_en_rs[i]   = spec_en_rn[i];
    assign rob_tag_rs[i]   = rat_alloc_en[i] ? rob_tag[i] : '0;
    assign retire_en[i]    = enable && !flush;
  end

  allis_table u_allis (
    .clk, .rst_n, .flush,
    .spec_en      (spec_en_rn),
    .rs1_use      (rs1_use_rn),
    .rs2_use      (rs2_use_rn),
    .rs1_addr     (rs1_addr_rn),
    .rs2_addr     (rs2_addr_rn),
    .ps1_tag      (ps1_tag_rs),
    .ps2_tag      (ps2_tag_rs),
    .tag1_valid   (tag1_valid_rs),
    .tag2_valid   (tag2_valid_rs),
    .alloc_en     (rat_alloc_en),
    .alloc_rd_addr(rd_addr_rn),
    .alloc_rob_tag(rob_tag),
    .rrat_en      (rrat_en),
    .rd_addr_cmt  (rd_addr_cmt),
    .rob_tag_cmt  (rob_tag_cmt),
    .rat_en       (rat_en),
    .path_sel     (path_sel)
  );

  reorder_buffer u_rob (
    .clk, .rst_n, .flush,
    .alloc_en     (rob_alloc_en),
    .reg_write    (reg_write_rn),
    .is_brnch     ({valid_rn[1] && brch_en_rn[1],
                   valid_rn[0] && brch_en_rn[0]}),
    .is_store     (store_en_rn),
    .spec_en      (spec_en_rn),
    .state_valid  (state_valid_rn),
    .brch_state   (brch_state_rn),
    .rd_addr      (rd_addr_rn),
    .rob_tag,
    .rob_valid,
    .stall,
    .wback_en     (wback_en),
    .rob_tag_wb   (rob_tag_wb),
    .brch_taken_wb(brch_taken_wb),
    .retire_en    (retire_en),
    .rrat_en      (rrat_en),
    .rd_addr_cmt  (rd_addr_cmt),
    .rob_tag_cmt  (rob_tag_cmt),
    .rat_en       (rat_en),
    .path_sel     (path_sel),
    .stb_en       (stb_en)
  );

endmodule
