`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import cpu_txn_pkg::*;
import commit_txn_pkg::*;

// Compares DUT commit stream against predictor / reference model.
module cpu_scoreboard;
  int unsigned n_cmp;
  int unsigned n_err;

  function automatic void reset();
    n_cmp = 0;
    n_err = 0;
  endfunction

  function automatic bit check_commit(
    input commit_txn_t dut,
    input commit_txn_t exp,
    input string tag = ""
  );
    bit ok;
    ok = (dut.rrat0_en === exp.rrat0_en) &&
         (dut.rrat1_en === exp.rrat1_en) &&
         (dut.stb0_en  === exp.stb0_en)  &&
         (dut.stb1_en  === exp.stb1_en)  &&
         (dut.rat0_en  === exp.rat0_en)  &&
         (dut.rat1_en  === exp.rat1_en)  &&
         (dut.rd0      === exp.rd0)      &&
         (dut.rd1      === exp.rd1);
    n_cmp++;
    if (!ok) begin
      n_err++;
      $error("[%s] commit mismatch #%0d\n  dut: %s\n  exp: %s",
             (tag == "") ? "cpu_scoreboard" : tag, n_cmp,
             commit_txn_str(dut), commit_txn_str(exp));
    end
    return ok;
  endfunction

  function automatic void report(input string tag = "cpu_scoreboard");
    if (n_err == 0)
      $display("[%s] PASS  compared=%0d", tag, n_cmp);
    else
      $display("[%s] FAIL  compared=%0d errors=%0d", tag, n_cmp, n_err);
  endfunction

  initial reset();
endmodule
