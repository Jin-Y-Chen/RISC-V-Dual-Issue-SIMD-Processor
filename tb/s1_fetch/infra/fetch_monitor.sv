`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import cpu_txn_pkg::*;

module fetch_monitor (
  cpu_if.mon vif
);
  function automatic cpu_txn_t sample();
    cpu_txn_t t;
    t = cpu_txn_clear();
    t.valid  = vif.i0_valid || vif.i1_valid;
    t.flush  = vif.flush;
    t.enable = vif.enable;
    t.pc0    = vif.pc0;
    t.pc1    = vif.pc1;
    return t;
  endfunction
endmodule
