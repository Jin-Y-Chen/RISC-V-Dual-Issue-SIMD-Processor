`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import cpu_txn_pkg::*;

// Drives cpu_if from cpu_txn_t (hold through DUT sample edge).
module cpu_driver (
  cpu_if.drv vif
);
  task automatic drive(input cpu_txn_t t);
    vif.enable          = t.enable;
    vif.flush           = t.flush;
    vif.dispatch_stall  = 1'b0;
    vif.spec0_stall     = 1'b0;
    vif.spec1_stall     = 1'b0;
    vif.i0_pred_taken   = 1'b0;
    vif.i1_pred_taken   = 1'b0;
    vif.i0_brch_recover = 1'b0;
    vif.i1_brch_recover = 1'b0;
    vif.i0_pc_execute   = '0;
    vif.i1_pc_execute   = '0;
  endtask

  task automatic clear();
    drive(cpu_txn_clear());
  endtask

  initial clear();
endmodule
