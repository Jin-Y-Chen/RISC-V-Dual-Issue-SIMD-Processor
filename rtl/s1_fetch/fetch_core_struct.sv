`timescale 1ns / 1ps

// S1 fetch structure — PC + instruction cache + branch target buffer (dual-issue pair).
// All slot-indexed ports are [2] arrays: index 0 = I0, index 1 = I1.
// Speculation: per-lane registered flags loop through pc <-> pc_selector, and the
// next-spec pair is exported directly as spec_en.
// Mode (+4/+4 vs +8/+8) is computed inside pc from spec_in[0] ^ spec_in[1].
// Nested-speculation freeze comes from decode target_predict (spec_stall).
import rv_dis_pkg::*;

module s1_fetch_struct #(
  parameter word_t RESET_PC = RESET_PC_INIT
) (
  // external controls
  input  logic          clk,
  input  logic          rst_n,
  input  logic          enable,

  // internal controls
  input  logic          dispatch_stall,
  input  logic          spec_stall   [2],
  input  logic          pred_taken   [2],
  input  logic          brch_recover [2],
  input  logic          valid_wb     [2],

  // input data
  input  word_t         pc_execute   [2],
  input  word_t         pc_wb        [2],
  input  word_t         pc_target_wb [2], // decode pc_predict: BTB train + pc_selector steer

  // output data
  output word_t         pc_if        [2],
  output word_t         pc_target    [2], // BTB lookup → IF/ID / decode
  output instr_t        instr        [2],

  // output controls
  output logic          spec_en      [2],
  output logic          valid        [2],
  output logic          target_valid [2]
);

  // Registered speculation state (pc) and the next-PC bases (pc_selector).
  logic  spec    [2];
  word_t pc_next [2];

  pc #(
    .RESET_PC(RESET_PC)
  ) u_pc (
    // inputs — controls / next-PC bases
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .dispatch_stall (dispatch_stall),
    .spec_stall     (spec_stall),
    .spec_in        (spec_en),
    .pc_in          (pc_next),
    // outputs — registered PC / speculation
    .pc_out         (pc_if),
    .spec_out       (spec)
  );

  instruction_cache u_icache (
    // inputs
    .clk   (clk),
    .rst_n (rst_n),
    .pc    (pc_if),
    // outputs
    .instr (instr),
    .valid (valid)
  );

  target_buffer u_target (
    // inputs — lookup PC + WB train
    .clk          (clk),
    .rst_n        (rst_n),
    .pc           (pc_if),
    .valid_wb     (valid_wb),
    .pc_wb        (pc_wb),
    .pc_target_wb (pc_target_wb),
    // outputs — predicted targets
    .valid        (target_valid),
    .pc_target    (pc_target)
  );

  pc_selector u_pc_sel (
    // inputs — steer / recover / current PC; steer target = decode pc_predict
    .spec_in      (spec),
    .pred_taken   (pred_taken),
    .brch_recover (brch_recover),
    .pc_in        (pc_if),
    .pc_target    (pc_target_wb),
    .pc_execute   (pc_execute),
    // outputs — next-spec + next-PC bases → pc
    .spec_out     (spec_en),
    .pc_out       (pc_next)
  );

endmodule
