`timescale 1ns / 1ps

// Template for new unit testbenches. Copy to <module>_tb.sv and fill in tests.
// Vivado: include path = sim/tb, simulation top = <module>_tb
module tb_template;

  import spu_lite_pkg::*;

  `include "tb_console.svh"

  int pass_cnt;
  int fail_cnt;

  // DUT ports and dut instance here

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("tb_template - rename me");
    tb_info_msg("PASS format: <test> | <op>, operands, result/behavior");

    // Example:
    // tb_pass_detail("test1", "OP, rs1=..., rs2=..., result=...");
    // pass_cnt++;

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "tb_template failed");
    $finish;
  end

endmodule
