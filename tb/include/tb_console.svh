`ifndef TB_CONSOLE_SVH
`define TB_CONSOLE_SVH

// Shared testbench logging (required in all tb/<unit>/*_tb.sv).
//
// From tb/<unit>/*_tb.sv:
//   `include "../include/tb_console.svh"
// Include path for sim drivers: -I <repo>/tb
//
// Multi-line result format (tb_report_open + tb_field_* + tb_report_close):
//   [PASS] beq_taken | BEQ x1,x2,+8
//
//     brch_taken      =                  0 (exp: 0)
//     brch_target     =       0x00001008 (exp: 0x00001008)
//   ---------------------------------------
//
// Labels use full DUT / pipeline signal names.
// End every TB with tb_summary(pass_cnt, fail_cnt) for run_yosys.ps1.

task automatic tb_pass_msg(input string msg);
  $display("[PASS] %s", msg);
endtask

task automatic tb_pass_detail(input string name, input string detail);
  $display("[PASS] %s | %s", name, detail);
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
    $display("*** SUMMARY: %0d passed, %0d FAILED ***", passed, failed);
endtask

// Sample on negedge (clock # delays live in the TB clock generator only).
task automatic tb_advance(ref logic clk);
  @(negedge clk);
endtask

// --- Multi-line PASS/FAIL report (use inside check_expect) ---

task automatic tb_case_sep();
  $display("---------------------------------------");
endtask

task automatic tb_field_line(input string label, input string got_s, input string exp_s);
  // Literal format only - some simulators do not support $display(fmt, ...) with runtime fmt.
  $display("  %-16s = %18s (exp: %s)", label, got_s, exp_s);
endtask

task automatic tb_log_section(input string title);
  $display("  --- %s ---", title);
endtask

task automatic tb_field_in_bit(input string label, input logic val);
  $display("  %-16s = %18s", label, $sformatf("%0d", val));
endtask

task automatic tb_field_in_u32(input string label, input logic [31:0] val);
  $display("  %-16s = %18s", label, $sformatf("0x%08h", val));
endtask

task automatic tb_field_in_u2(input string label, input logic [1:0] val);
  $display("  %-16s = %18s", label, $sformatf("%02b", val));
endtask

task automatic tb_field_bit(input string label, input logic got, input logic exp);
  tb_field_line(label, $sformatf("%0d", got), $sformatf("%0d", exp));
endtask

task automatic tb_field_u2(input string label, input logic [1:0] got, input logic [1:0] exp);
  tb_field_line(label, $sformatf("%02b", got), $sformatf("%02b", exp));
endtask

task automatic tb_field_u5(input string label, input logic [4:0] got, input logic [4:0] exp);
  tb_field_line(label, $sformatf("%0d", got), $sformatf("%0d", exp));
endtask

task automatic tb_field_u32(input string label, input logic [31:0] got, input logic [31:0] exp);
  tb_field_line(label, $sformatf("0x%08h", got), $sformatf("0x%08h", exp));
endtask

task automatic tb_field_u32_note(input string label, input logic [31:0] val, input string note);
  tb_field_line(label, $sformatf("0x%08h", val), note);
endtask

task automatic tb_field_be(input string label, input logic [3:0] got, input logic [3:0] exp);
  tb_field_line(label, $sformatf("%04b", got), $sformatf("%04b", exp));
endtask

task automatic tb_field_op7(input string label, input logic [6:0] got, input logic [6:0] exp);
  tb_field_line(label, $sformatf("%07b", got), $sformatf("%07b", exp));
endtask

task automatic tb_field_f3(input string label, input logic [2:0] got, input logic [2:0] exp);
  tb_field_line(label, $sformatf("%0d", got), $sformatf("%0d", exp));
endtask

task automatic tb_field_f7(input string label, input logic [6:0] got, input logic [6:0] exp);
  tb_field_line(label, $sformatf("0x%02h", got), $sformatf("0x%02h", exp));
endtask

task automatic tb_field_lane(
  input string label,
  input logic got,
  input logic exp
);
  string got_s;
  string exp_s;
  // Avoid string ternaries - XSim can FATAL on them as task args.
  if (got)
    got_s = "ODD (1)";
  else
    got_s = "EVEN (0)";
  if (exp)
    exp_s = "ODD (1)";
  else
    exp_s = "EVEN (0)";
  tb_field_line(label, got_s, exp_s);
endtask

task automatic tb_report_open(input bit pass, input string name, input string detail);
  if (pass)
    $display("[PASS] %s | %s", name, detail);
  else
    $error("[FAIL] %s | %s", name, detail);
  $display("");
endtask

task automatic tb_report_close(input bit pass);
  bit _ack;
  _ack = pass;
  tb_case_sep();
endtask

task automatic tb_fail_field_bit(
  input string name,
  input string detail,
  input string label,
  input logic  got,
  input logic  exp
);
  tb_report_open(0, name, detail);
  tb_field_bit(label, got, exp);
  tb_report_close(0);
endtask

task automatic tb_fail_detail(input string name, input string detail);
  tb_report_open(0, name, detail);
  tb_field_line("note", detail, "-");
  tb_report_close(0);
endtask

// TRACE_VCD (set by run-sim): writes trace.vcd in the simulator working directory.
`ifdef TRACE_VCD
initial begin
  $dumpfile("trace.vcd");
  $dumpvars(0);
end
`endif

`endif // TB_CONSOLE_SVH
