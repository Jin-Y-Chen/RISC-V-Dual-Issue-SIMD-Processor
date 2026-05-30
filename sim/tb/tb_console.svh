// Shared testbench logging (required in all sim/tb/*_tb.sv).
//
// Vivado: add include path sim/tb, then inside each testbench module:
//   `include "tb_console.svh"
//
// Tcl Console does not show ANSI colors; use GUI Messages for Error/Warning icons.
//
// Prefer tb_pass_detail / tb_fail_detail for lines with operation + operands.
// End every TB with tb_summary(pass_cnt, fail_cnt) for copy_logs.ps1.
//
// New TBs: copy tb_template.sv from this folder.

task automatic tb_pass_msg(input string msg);
  $display("[PASS] %s", msg);
endtask

// [PASS] <name> | <detail>  e.g. xor | XOR, rs1=..., rs2=..., result=...
task automatic tb_pass_detail(input string name, input string detail);
  $display("[PASS] %-10s | %s", name, detail);
endtask

task automatic tb_warn_msg(input string msg);
  $warning("========================================");
  $warning("[WARN] %s", msg);
  $warning("========================================");
endtask

task automatic tb_fail_msg(input string msg);
  $error("========================================");
  $error("[FAIL] %s", msg);
  $error("========================================");
endtask

task automatic tb_fail_detail(input string name, input string detail);
  $error("========================================");
  $error("[FAIL] %-10s | %s", name, detail);
  $error("========================================");
endtask

task automatic tb_info_msg(input string msg);
  $display("[INFO] %s", msg);
endtask

task automatic tb_banner(input string msg);
  $display("========================================");
  $display("[INFO] %s", msg);
  $display("========================================");
endtask

task automatic tb_summary(input int passed, input int failed);
  if (failed == 0)
    $display("*** SUMMARY: %0d passed, 0 failed - OK ***", passed);
  else
    $error("*** SUMMARY: %0d passed, %0d FAILED ***", passed, failed);
endtask
