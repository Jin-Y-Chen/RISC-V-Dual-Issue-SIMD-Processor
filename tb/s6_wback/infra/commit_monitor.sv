`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import commit_txn_pkg::*;

module commit_monitor (
  commit_if.mon vif
);
  function automatic commit_txn_t sample();
    commit_txn_t t;
    t = commit_txn_clear();
    t.rrat0_en = vif.rrat0_en;
    t.rrat1_en = vif.rrat1_en;
    t.stb0_en  = vif.stb0_en;
    t.stb1_en  = vif.stb1_en;
    t.rat0_en  = vif.rat0_en;
    t.rat1_en  = vif.rat1_en;
    t.rd0      = vif.i0_rd_addr_cmt;
    t.rd1      = vif.i1_rd_addr_cmt;
    t.rob0     = vif.i0_rob_idx_cmt;
    t.rob1     = vif.i1_rob_idx_cmt;
    t.path0    = vif.i0_path_sel;
    t.path1    = vif.i1_path_sel;
    return t;
  endfunction
endmodule
