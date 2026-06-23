`timescale 1ns / 1ps

// S1 fetch structure — PC + instruction cache + branch target buffer (dual-issue pair).
module s1_fetch_struct
  import rv_dis_pkg::*;
#(
  parameter pc_t RESET_PC = pc_t'(32'h0000_0000)
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  // internal controls
  input  logic        stall_i,
  input  logic        set,

  // input data
  input  pc_t         set_pc,
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  pc_t         i0_pc_wb,
  input  pc_t         i1_pc_wb,
  input  pc_t         i0_target_wb,
  input  pc_t         i1_target_wb,

  // output data
  output pc_t         pc0,
  output pc_t         pc1,
  output pc_t         i0_pc_target,
  output pc_t         i1_pc_target,
  output instr_t      instr0,
  output instr_t      instr1
);

  pc #(
    .RESET_PC(RESET_PC)
  ) u_pc (
    // external controls
    .clk    (clk),
    .rst_n  (rst_n),
    .enable (enable),
    // internal controls
    .stall  (stall_i),
    .set    (set),
    // input data
    .set_pc (set_pc),
    // output data
    .pc0    (pc0),
    .pc1    (pc1)
  );

  instruction_cache u_icache (
    // external controls
    .clk    (clk),
    .rst_n  (rst_n),
    // input data
    .pc0    (pc0),
    .pc1    (pc1),
    // output data
    .instr0 (instr0),
    .instr1 (instr1)
  );

  target_buffer u_target (
    // input data — fetch lookup
    .i0_pc          (pc0),
    .i1_pc          (pc1),
    // input data — WB retire
    .i0_valid_wb    (i0_valid_wb),
    .i1_valid_wb    (i1_valid_wb),
    .i0_pc_wb       (i0_pc_wb),
    .i1_pc_wb       (i1_pc_wb),
    .i0_target_wb   (i0_target_wb),
    .i1_target_wb   (i1_target_wb),
    // output data
    .i0_pc_target   (i0_pc_target),
    .i1_pc_target   (i1_pc_target)
  );

endmodule
