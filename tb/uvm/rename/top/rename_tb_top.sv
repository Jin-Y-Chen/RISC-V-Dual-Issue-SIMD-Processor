`timescale 1ns/1ps
`include "uvm_macros.svh"

module rename_tb_top;
  import uvm_pkg::*;
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rename_uvm_pkg::*;

  logic clk = 0;
  rename_if vif(clk);

  always #5ns clk = ~clk;

  rename_core_struct dut (
    .clk(clk),
    .rst_n(vif.rst_n),
    .flush(vif.flush),
    .stall_rn(1'b0),
    .enable(1'b1),
    .spec_en_rn(vif.spec_en_rn),
    .valid_rn(vif.valid_rn),
    .reg_write_rn(vif.reg_write_rn),
    .store_en_rn(vif.store_en_rn),
    .brch_en_rn(vif.brch_en_rn),
    .state_valid_rn(vif.state_valid_rn),
    .brch_state_rn(vif.brch_state_rn),
    .rs1_use_rn(vif.rs1_use_rn),
    .rs2_use_rn(vif.rs2_use_rn),
    .rd_addr_rn(vif.rd_addr_rn),
    .rs1_addr_rn(vif.rs1_addr_rn),
    .rs2_addr_rn(vif.rs2_addr_rn),
    .wback_en(vif.wback_en),
    .rob_tag_wb(vif.rob_tag_wb),
    .brch_taken_wb(vif.brch_taken_wb),
    .prf_ready(vif.prf_ready),
    .stall(vif.stall),
    .valid_rs(vif.valid_rs),
    .spec_en_rs(vif.spec_en_rs),
    .ps1_tag_rs(vif.ps1_tag_rs),
    .ps2_tag_rs(vif.ps2_tag_rs),
    .tag_ready_rs(vif.tag_ready_rs),
    .rob_tag_rs(vif.rob_tag_rs)
  );

  initial begin
    vif.rst_n = 0;
    vif.flush = 0;
    vif.prf_ready = '1;
    foreach (vif.spec_en_rn[i]) begin
      vif.spec_en_rn[i]      = 0;
      vif.valid_rn[i]        = 0;
      vif.reg_write_rn[i]    = 0;
      vif.store_en_rn[i]     = 0;
      vif.brch_en_rn[i]      = 0;
      vif.state_valid_rn[i]  = 0;
      vif.brch_state_rn[i]   = '0;
      vif.rs1_use_rn[i]      = 0;
      vif.rs2_use_rn[i]      = 0;
      vif.rd_addr_rn[i]      = '0;
      vif.rs1_addr_rn[i]     = '0;
      vif.rs2_addr_rn[i]     = '0;
      vif.wback_en[i]        = 0;
      vif.rob_tag_wb[i]      = '0;
      vif.brch_taken_wb[i]   = 0;
    end
    repeat (4) @(posedge clk);
    vif.rst_n = 1;
  end

  initial begin
    string testname;
    uvm_config_db#(virtual rename_if)::set(null, "uvm_test_top", "vif", vif);
    if (!$value$plusargs("UVM_TESTNAME=%s", testname))
      testname = "rename_smoke_test";
    run_test(testname);
  end

  initial begin
    #1ms;
    `uvm_fatal("TIMEOUT", "rename UVM test exceeded 1 ms")
  end
endmodule
