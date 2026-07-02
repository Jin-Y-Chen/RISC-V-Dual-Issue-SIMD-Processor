// Shared testbench logging (required in all tb/<unit>/*_tb.sv).
//
// From tb/<unit>/*_tb.sv:
//   `include "../common/tb_console.svh"
// Include path for Verilator: -I <repo>/tb
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

// Posedge then negedge: NBA updates are visible (Verilator #0 / #1step timing).
task automatic tb_advance(input logic clk);
  @(posedge clk);
  @(negedge clk);
endtask

// --- Multi-line PASS/FAIL report (use inside check_expect) ---

task automatic tb_case_sep();
  $display("---------------------------------------");
endtask

localparam int TB_FIELD_VAL_W = 18;

task automatic tb_field_line(input string label, input string got_s, input string exp_s);
  string fmt;
  fmt = $sformatf("  %%-16s = %%%0ds (exp: %%s)", TB_FIELD_VAL_W);
  $display(fmt, label, got_s, exp_s);
endtask

task automatic tb_field_bit(input string label, input logic got, input logic exp);
  tb_field_line(label, $sformatf("%0d", got), $sformatf("%0d", exp));
endtask

task automatic tb_field_u5(input string label, input logic [4:0] got, input logic [4:0] exp);
  tb_field_line(label, $sformatf("%0d", got), $sformatf("%0d", exp));
endtask

task automatic tb_field_u32(input string label, input logic [31:0] got, input logic [31:0] exp);
  tb_field_line(label, $sformatf("0x%08h", got), $sformatf("0x%08h", exp));
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
  tb_field_line(label,
                got ? "ODD (1)" : "EVEN (0)",
                exp ? "ODD (1)" : "EVEN (0)");
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
