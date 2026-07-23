`timescale 1ns / 1ps

import rv_dis_pkg::*;
import dpi_pkg::*;

// DPI shim — golden logic in model/s1_fetch/instruction_cache_gm.cpp
module instruction_cache_gm (
  input  word_t  pc0,
  input  word_t  pc1,
  output instr_t instr0,
  output instr_t instr1,
  output logic   i0_valid,
  output logic   i1_valid
);

  int i0, i1, v0, v1;

  always @(*) begin
    icache_dpi_eval(int'(pc0), int'(pc1), i0, i1, v0, v1);
    instr0   = i0[31:0];
    instr1   = i1[31:0];
    i0_valid = v0[0];
    i1_valid = v1[0];
  end

endmodule
