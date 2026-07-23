`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import memory_txn_pkg::*;

module memory_monitor (
  memory_if.mon vif
);
  function automatic memory_txn_t sample_dmem();
    memory_txn_t t;
    t = memory_txn_clear();
    t.req    = vif.dmem_req;
    t.we     = vif.dmem_we;
    t.addr   = vif.dmem_addr;
    t.wdata  = vif.dmem_wdata;
    t.rdata  = vif.dmem_rdata;
    t.rvalid = vif.dmem_rvalid;
    return t;
  endfunction
endmodule
