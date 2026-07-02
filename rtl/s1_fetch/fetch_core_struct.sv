`timescale 1ns / 1ps

// S1 fetch structure — PC + instruction cache + branch target buffer (dual-issue pair).
module s1_fetch_struct
  import rv_dis_pkg::*;
#(
  parameter word_t RESET_PC = word_t'(32'h0000_0000)
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        stall_i,
  input  logic        set,
  input  logic        i0_pred_taken,
  input  logic        i1_pred_taken,
  input  logic        recover_en,
  input  logic        recover_correct,
  input  logic        recover_i0,
  input  logic        recover_i1,
  input  logic        recover_use_exec_pc,

  // input data
  input  word_t         set_pc,
  input  word_t         recover_pc,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  word_t         i0_pc_wb,
  input  word_t         i1_pc_wb,
  input  word_t         i0_target_wb,
  input  word_t         i1_target_wb,

  // output data
  output logic        flush_fetch,
  output word_t         pc0,
  output word_t         pc1,
  output word_t         i0_pc_target,
  output word_t         i1_pc_target,
  output instr_t      instr0,
  output instr_t      instr1
);

  word_t pc0_s;
  word_t pc1_s;
  word_t i0_pc_target_s;
  word_t i1_pc_target_s;
  logic  spec_q;
  logic  spec_next;
  logic  spec_en;
  word_t spec_out_sel;
  word_t norm_out_sel;
  word_t spec_in_mux;
  word_t norm_in_mux;
  word_t set_pc_aligned;

  assign set_pc_aligned = word_t'({set_pc[31:2], 2'b00});
  assign spec_en        = (spec_q | spec_next) & ~set;
  assign spec_in_mux    = set ? (set_pc_aligned - word_t'(32'd4)) : spec_out_sel;
  assign norm_in_mux    = set ? (set_pc_aligned - word_t'(32'd8)) : norm_out_sel;

  pc #(
    .RESET_PC(RESET_PC)
  ) u_pc (
    .clk       (clk),
    .rst_n     (rst_n),
    .enable    (enable),
    .stall     (stall_i),
    .spec_en   (spec_en),
    .spec_in   (spec_in_mux),
    .norm_in   (norm_in_mux),
    .pc0_out   (pc0_s),
    .pc1_out   (pc1_s)
  );

  assign pc0 = pc0_s;
  assign pc1 = pc1_s;

  always_ff @(posedge clk) begin
    if (!rst_n)
      spec_q <= 1'b0;
    else if (set)
      spec_q <= 1'b0;
    else
      spec_q <= spec_next;
  end

  instruction_cache u_icache (
    .pc0    (pc0_s),
    .pc1    (pc1_s),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  target_buffer u_target (
    .i0_pc          (pc0_s),
    .i1_pc          (pc1_s),
    .i0_valid_wb    (i0_valid_wb),
    .i1_valid_wb    (i1_valid_wb),
    .i0_pc_wb       (i0_pc_wb),
    .i1_pc_wb       (i1_pc_wb),
    .i0_target_wb   (i0_target_wb),
    .i1_target_wb   (i1_target_wb),
    .i0_pc_target   (i0_pc_target_s),
    .i1_pc_target   (i1_pc_target_s)
  );

  assign i0_pc_target = i0_pc_target_s;
  assign i1_pc_target = i1_pc_target_s;

  pc_selector u_pc_sel (
    .enable              (enable),
    .in_spec             (spec_q),
    .pc0                 (pc0_s),
    .pc1                 (pc1_s),
    .i0_pc_predict       (i0_pc_target_s),
    .i0_pred_taken       (i0_pred_taken),
    .recover_en          (recover_en),
    .recover_correct     (recover_correct),
    .recover_i0          (recover_i0),
    .recover_pc          (recover_pc),
    .recover_use_exec_pc (recover_use_exec_pc),
    .spec                (spec_next),
    .spec_out            (spec_out_sel),
    .norm_out            (norm_out_sel),
    .flush               (flush_fetch)
  );

endmodule
