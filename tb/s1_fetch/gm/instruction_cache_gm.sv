`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Golden model for rtl/s1_fetch/core_mod/instruction_cache.sv
// Reference = program/bin/demo_instructions.hex (@0x1000, sequential words).
// PC lookup only; miss => 32'h0. Not a set/way cache replica.

module instruction_cache_gm (
  input  word_t  pc0,
  input  word_t  pc1,
  output instr_t instr0,
  output instr_t instr1
);

  localparam word_t DEMO_BASE  = 32'h0000_1000;
  localparam int    DEMO_COUNT = 72;

  // Image from program/bin/demo_instructions.hex (regenerate LUT if hex changes).
  localparam word_t DEMO_WORD [0:DEMO_COUNT-1] = '{
    32'h00000537, 32'h00A00293, 32'h00000697, 32'h01400313,
    32'h005283B3, 32'h00752023, 32'h00A503B3, 32'h00052483,
    32'h0094C633, 32'h00752223, 32'h0AA00593, 32'h000005B7,
    32'h05500593, 32'h00000597, 32'h01100593, 32'h00052583,
    32'h06300593, 32'h000005B7, 32'h00400713, 32'h00072783,
    32'h00100813, 32'h00000837, 32'h00628033, 32'h00652423,
    32'h005003B3, 32'h00852403, 32'h006283B3, 32'h00752623,
    32'h405303B3, 32'h00C52403, 32'h006293B3, 32'h00752823,
    32'h0062A3B3, 32'h01052483, 32'h0062C3B3, 32'h00752A23,
    32'h005353B3, 32'h01452403, 32'h405353B3, 32'h00752C23,
    32'h0062E3B3, 32'h01852483, 32'h0062F3B3, 32'h00752E23,
    32'h00300293, 32'h04028263, 32'hFFF28293, 32'hFE029EE3,
    32'h00A00293, 32'h00052403, 32'h00500313, 32'h00534663,
    32'h00000393, 32'h02000263, 32'h00100393, 32'h00500293,
    32'h00452483, 32'h00A00313, 32'h00535663, 32'h00000413,
    32'h00000463, 32'h00200413, 32'h00000293, 32'h01C000EF,
    32'h06300493, 32'h01400313, 32'h00652023, 32'h006283B3,
    32'h00052403, 32'h00000063, 32'h02A00113, 32'h00008067
  };

  function automatic word_t demo_insn_at(input word_t pc);
    word_t key;
    int    idx;
    key = word_t'({pc[31:2], 2'b00});
    if (key < DEMO_BASE)
      return 32'h0;
    idx = int'((key - DEMO_BASE) >> 2);
    if (idx < 0 || idx >= DEMO_COUNT)
      return 32'h0;
    return DEMO_WORD[idx];
  endfunction

  assign instr0 = demo_insn_at(pc0);
  assign instr1 = demo_insn_at(pc1);

endmodule
