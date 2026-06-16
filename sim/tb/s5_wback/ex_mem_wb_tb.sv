`timescale 1ns / 1ps

// ex_mem_wb_tb — 4 lane copies, odd WB mux, direct GPR retire (push0/push1).
module ex_mem_wb_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        flush;
  logic        stall_i0;
  logic        stall_i1;

  logic        ev0_reg_write_ex;
  logic [4:0]  ev0_rd_addr_ex;
  logic [31:0] ev0_wdata_ex;
  logic [31:0] ev0_pc_ex;

  logic        ev1_reg_write_ex;
  logic [4:0]  ev1_rd_addr_ex;
  logic [31:0] ev1_wdata_ex;
  logic [31:0] ev1_pc_ex;

  logic        od0_reg_write_mem;
  logic [4:0]  od0_rd_addr_mem;
  logic [31:0] od0_pc_mem;
  logic        od0_use_link_mem;
  logic [31:0] od0_alu_result_mem;
  logic        od0_mem_en_mem;
  logic        od0_mem_act_mem;
  logic [31:0] od0_load_mem_data;

  logic        od1_reg_write_mem;
  logic [4:0]  od1_rd_addr_mem;
  logic [31:0] od1_pc_mem;
  logic        od1_use_link_mem;
  logic [31:0] od1_alu_result_mem;
  logic        od1_mem_en_mem;
  logic        od1_mem_act_mem;
  logic [31:0] od1_load_mem_data;

  logic        ev0_reg_write_exwb;
  logic [4:0]  ev0_rd_addr_exwb;
  logic [31:0] ev0_wdata_exwb;
  logic [31:0] ev0_pc_exwb;

  logic        ev1_reg_write_exwb;
  logic [4:0]  ev1_rd_addr_exwb;
  logic [31:0] ev1_wdata_exwb;
  logic [31:0] ev1_pc_exwb;

  logic [31:0] od0_wdata_mem;
  logic [31:0] od1_wdata_mem;

  logic        push0_valid;
  logic [4:0]  push0_rd;
  logic [31:0] push0_wdata;
  logic [31:0] push0_pc;

  logic        push1_valid;
  logic [4:0]  push1_rd;
  logic [31:0] push1_wdata;
  logic [31:0] push1_pc;

  int pass_cnt;
  int fail_cnt;

  ex_mem_wb dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_inputs;
    stall_i0 = 1'b0;
    stall_i1 = 1'b0;
    ev0_reg_write_ex = 1'b0;
    ev0_rd_addr_ex = '0;
    ev0_wdata_ex = '0;
    ev0_pc_ex = '0;
    ev1_reg_write_ex = 1'b0;
    ev1_rd_addr_ex = '0;
    ev1_wdata_ex = '0;
    ev1_pc_ex = '0;
    od0_reg_write_mem = 1'b0;
    od0_rd_addr_mem = '0;
    od0_pc_mem = '0;
    od0_use_link_mem = 1'b0;
    od0_alu_result_mem = '0;
    od0_mem_en_mem = 1'b0;
    od0_mem_act_mem = 1'b0;
    od0_load_mem_data = '0;
    od1_reg_write_mem = 1'b0;
    od1_rd_addr_mem = '0;
    od1_pc_mem = '0;
    od1_use_link_mem = 1'b0;
    od1_alu_result_mem = '0;
    od1_mem_en_mem = 1'b0;
    od1_mem_act_mem = 1'b0;
    od1_load_mem_data = '0;
  endtask

  task automatic check_ev0_exwb(
    input string       name,
    input string       detail,
    input logic        exp_rw,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wdata,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (ev0_reg_write_exwb === exp_rw) && (ev0_rd_addr_exwb === exp_rd) &&
           (ev0_wdata_exwb === exp_wdata) && (ev0_pc_exwb === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("ev0_reg_write_exwb", ev0_reg_write_exwb, exp_rw);
    tb_field_u5("ev0_rd_addr_exwb", ev0_rd_addr_exwb, exp_rd);
    tb_field_u32("ev0_wdata_exwb", ev0_wdata_exwb, exp_wdata);
    tb_field_u32("ev0_pc_exwb", ev0_pc_exwb, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_od0_wdata(
    input string       name,
    input string       detail,
    input logic [31:0] exp_wdata
  );
    bit pass;
    pass = (od0_wdata_mem === exp_wdata);
    tb_report_open(pass, name, detail);
    tb_field_u32("od0_wdata_mem", od0_wdata_mem, exp_wdata);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_push0(
    input string       name,
    input string       detail,
    input logic        exp_valid,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wdata,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (push0_valid === exp_valid) && (!exp_valid ||
            ((push0_rd === exp_rd) && (push0_wdata === exp_wdata) && (push0_pc === exp_pc)));
    tb_report_open(pass, name, detail);
    tb_field_bit("push0_valid", push0_valid, exp_valid);
    if (exp_valid) begin
      tb_field_u5("push0_rd", push0_rd, exp_rd);
      tb_field_u32("push0_wdata", push0_wdata, exp_wdata);
      tb_field_u32("push0_pc", push0_pc, exp_pc);
    end
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_push1(
    input string       name,
    input string       detail,
    input logic        exp_valid,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_wdata
  );
    bit pass;
    pass = (push1_valid === exp_valid) && (!exp_valid ||
            (push1_rd === exp_rd && push1_wdata === exp_wdata));
    tb_report_open(pass, name, detail);
    tb_field_bit("push1_valid", push1_valid, exp_valid);
    if (exp_valid) begin
      tb_field_u5("push1_rd", push1_rd, exp_rd);
      tb_field_u32("push1_wdata", push1_wdata, exp_wdata);
    end
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear_inputs();
    rst_n = 1'b0;
    tick();
    rst_n = 1'b1;
    tick();

    tb_banner("ex_mem_wb_tb - pipeline regs + direct GPR retire");

    check_ev0_exwb("reset_bubble", "EX/WB cleared",
                   1'b0, 5'd0, 32'd0, 32'd0);
    check_push0("reset_push0", "no retire candidate", 1'b0, 5'd0, 32'd0, 32'd0);

    ev0_reg_write_ex = 1'b1;
    ev0_rd_addr_ex   = 5'd2;
    ev0_wdata_ex     = 32'h1234_5678;
    ev0_pc_ex        = 32'h0000_1000;
    tick();
    check_ev0_exwb("ev0_capture", "even I0 latched to EX/WB",
                   1'b1, 5'd2, 32'h1234_5678, 32'h0000_1000);
    check_push0("ev0_push0", "even I0 retire candidate",
                1'b1, 5'd2, 32'h1234_5678, 32'h0000_1000);

    clear_inputs();
    od0_reg_write_mem = 1'b1;
    od0_rd_addr_mem   = 5'd7;
    od0_pc_mem        = 32'h0000_2000;
    od0_mem_en_mem    = 1'b1;
    od0_mem_act_mem   = 1'b0;
    od0_load_mem_data = 32'hDEAD_BEEF;
    tick();
    check_od0_wdata("od0_load_mux", "load uses mem_data",
                      32'hDEAD_BEEF);
    check_push0("od0_load_push0", "odd I0 load retire",
                1'b1, 5'd7, 32'hDEAD_BEEF, 32'h0000_2000);

    clear_inputs();
    od0_reg_write_mem  = 1'b1;
    od0_rd_addr_mem    = 5'd1;
    od0_pc_mem         = 32'h0000_3000;
    od0_use_link_mem   = 1'b1;
    od0_alu_result_mem = 32'h1111_1111;
    #1;
    check_od0_wdata("od0_link_mux", "JAL link = pc+4",
                    32'h0000_3004);

    clear_inputs();
    od0_reg_write_mem  = 1'b1;
    od0_rd_addr_mem    = 5'd3;
    od0_pc_mem         = 32'h0000_4000;
    od0_alu_result_mem = 32'h0004_5000;
    #1;
    check_od0_wdata("od0_lui_mux", "LUI/AUIPC uses reg_wdata path",
                    32'h0004_5000);

    clear_inputs();
    ev0_reg_write_ex = 1'b1;
    ev0_rd_addr_ex   = 5'd9;
    ev0_wdata_ex     = 32'h1;
    ev0_pc_ex        = 32'h5000;
    tick();
    ev0_wdata_ex = 32'h9999_9999;
    stall_i0 = 1'b1;
    tick();
    check_ev0_exwb("stall_i0_hold", "stall_i0 holds EX/WB",
                   1'b1, 5'd9, 32'h1, 32'h5000);
    check_push0("stall_i0_no_push", "stalled slot does not push",
                1'b0, 5'd0, 32'd0, 32'd0);
    stall_i0 = 1'b0;
    tick();
    check_ev0_exwb("stall_i0_release", "capture after stall clears",
                   1'b1, 5'd9, 32'h9999_9999, 32'h5000);

    clear_inputs();
    ev0_reg_write_ex = 1'b1;
    ev0_rd_addr_ex   = 5'd10;
    ev0_wdata_ex     = 32'h2;
    ev0_pc_ex        = 32'h6004;
    od1_reg_write_mem = 1'b1;
    od1_rd_addr_mem   = 5'd11;
    od1_pc_mem        = 32'h6008;
    od1_alu_result_mem = 32'h3;
    tick();
    #1;
    check_push0("dual_slot_push", "I0 ev0 push", 1'b1, 5'd10, 32'h2, 32'h6004);
    check_push1("dual_slot_push1", "I1 od1 push", 1'b1, 5'd11, 32'h3);

    flush = 1'b1;
    tick();
    flush = 1'b0;
    clear_inputs();
    tick();
    check_ev0_exwb("flush_clear", "flush clears EX/WB",
                   1'b0, 5'd0, 32'd0, 32'd0);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "ex_mem_wb_tb failed");
    $finish;
  end

endmodule
