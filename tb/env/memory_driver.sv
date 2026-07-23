`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import memory_txn_pkg::*;

// Behavioral memory responder for memory_if (I-cache / D-mem stubs).
module memory_driver (
  memory_if.drv vif
);
  word_t imem [0:1023];
  word_t dmem [0:1023];

  task automatic load_imem_word(input int idx, input word_t data);
    if (idx >= 0 && idx < 1024) imem[idx] = data;
  endtask

  always_ff @(posedge vif.clk or negedge vif.rst_n) begin
    if (!vif.rst_n) begin
      vif.imem_rvalid0 <= 1'b0;
      vif.imem_rvalid1 <= 1'b0;
      vif.dmem_rvalid  <= 1'b0;
      vif.imem_rdata0  <= '0;
      vif.imem_rdata1  <= '0;
      vif.dmem_rdata   <= '0;
    end else begin
      vif.imem_rvalid0 <= vif.imem_req;
      vif.imem_rvalid1 <= vif.imem_req;
      vif.imem_rdata0  <= imem[vif.imem_addr0[11:2]];
      vif.imem_rdata1  <= imem[vif.imem_addr1[11:2]];
      if (vif.dmem_req && vif.dmem_we)
        dmem[vif.dmem_addr[11:2]] <= vif.dmem_wdata;
      vif.dmem_rvalid <= vif.dmem_req && !vif.dmem_we;
      vif.dmem_rdata  <= dmem[vif.dmem_addr[11:2]];
    end
  end
endmodule
