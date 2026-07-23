`timescale 1ns / 1ps

// Global scoreboard: compare DUT vs golden-model observations.
module tb_scoreboard;
  import tb_pkg::*;

  int pass_cnt = 0;
  int fail_cnt = 0;

  function automatic bit compare(
    input string    tag,
    input rob_obs_t dut,
    input rob_obs_t exp,
    input bit       quiet = 0
  );
    bit ok;
    ok = (dut.i0_rob_idx     === exp.i0_rob_idx)
      && (dut.i1_rob_idx     === exp.i1_rob_idx)
      && (dut.stall          === exp.stall)
      && (dut.i0_can_retire  === exp.i0_can_retire)
      && (dut.i1_can_retire  === exp.i1_can_retire)
      && (dut.rrat0_en       === exp.rrat0_en)
      && (dut.rrat1_en       === exp.rrat1_en)
      && (dut.i0_rd_addr_cmt === exp.i0_rd_addr_cmt)
      && (dut.i1_rd_addr_cmt === exp.i1_rd_addr_cmt)
      && (dut.i0_rob_idx_cmt === exp.i0_rob_idx_cmt)
      && (dut.i1_rob_idx_cmt === exp.i1_rob_idx_cmt)
      && (dut.rat0_en        === exp.rat0_en)
      && (dut.rat1_en        === exp.rat1_en)
      && (dut.i0_path_sel    === exp.i0_path_sel)
      && (dut.i1_path_sel    === exp.i1_path_sel)
      && (dut.stb0_en        === exp.stb0_en)
      && (dut.stb1_en        === exp.stb1_en)
      && (dut.head           === exp.head)
      && (dut.tail           === exp.tail)
      && (dut.occ            === exp.occ)
      && (dut.active_spec    === exp.active_spec);

    if (ok) begin
      pass_cnt++;
      if (!quiet)
        $display("[PASS] %s | %s", tag, obs_str(dut));
    end else begin
      fail_cnt++;
      $error("[FAIL] %s", tag);
      $display("  DUT: %s", obs_str(dut));
      $display("  EXP: %s", obs_str(exp));
      if (dut.stall !== exp.stall)
        $display("    mismatch stall: dut=%0d exp=%0d", dut.stall, exp.stall);
      if (dut.i0_can_retire !== exp.i0_can_retire || dut.i1_can_retire !== exp.i1_can_retire)
        $display("    mismatch can_retire: dut=%0d%0d exp=%0d%0d",
                 dut.i0_can_retire, dut.i1_can_retire,
                 exp.i0_can_retire, exp.i1_can_retire);
      if (dut.head !== exp.head || dut.tail !== exp.tail || dut.occ !== exp.occ)
        $display("    mismatch ptr: dut h/t/o=%0d/%0d/%0d exp=%0d/%0d/%0d",
                 dut.head, dut.tail, dut.occ, exp.head, exp.tail, exp.occ);
      if (dut.active_spec !== exp.active_spec)
        $display("    mismatch active_spec: dut=%0d exp=%0d",
                 dut.active_spec, exp.active_spec);
    end
    return ok;
  endfunction

  function automatic void summary();
    $display("========================================");
    if (fail_cnt == 0)
      $display("PASS — %0d checks, 0 failures", pass_cnt);
    else
      $display("FAIL — %0d passed, %0d failed", pass_cnt, fail_cnt);
    $display("========================================");
  endfunction

endmodule
