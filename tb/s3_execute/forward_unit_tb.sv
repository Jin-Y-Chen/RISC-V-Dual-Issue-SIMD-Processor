`timescale 1ns / 1ps

// forward_unit_tb — WB wb0/wb1 -> EX combinational bypass.
module forward_unit_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic        ev0_enable;
  logic [4:0]  ev0_rs1_addr;
  logic [4:0]  ev0_rs2_addr;
  logic [31:0] ev0_rs1_data;
  logic [31:0] ev0_rs2_data;

  logic        ev1_enable;
  logic [4:0]  ev1_rs1_addr;
  logic [4:0]  ev1_rs2_addr;
  logic [31:0] ev1_rs1_data;
  logic [31:0] ev1_rs2_data;

  logic        od0_enable;
  logic [4:0]  od0_rs1_addr;
  logic [4:0]  od0_rs2_addr;
  logic [31:0] od0_rs1_data;
  logic [31:0] od0_rs2_data;

  logic        od1_enable;
  logic [4:0]  od1_rs1_addr;
  logic [4:0]  od1_rs2_addr;
  logic [31:0] od1_rs1_data;
  logic [31:0] od1_rs2_data;

  logic        wb0_reg_write;
  logic [4:0]  wb0_rd_addr;
  logic [31:0] wb0_data;
  logic [31:0] wb0_pc;
  logic        wb1_reg_write;
  logic [4:0]  wb1_rd_addr;
  logic [31:0] wb1_data;
  logic [31:0] wb1_pc;

  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;

  int pass_cnt;
  int fail_cnt;

  forward_unit dut (.*);

  task automatic clear_inputs;
    ev0_enable = 1'b0; ev0_rs1_addr = '0; ev0_rs2_addr = '0;
    ev0_rs1_data = '0; ev0_rs2_data = '0;
    ev1_enable = 1'b0; ev1_rs1_addr = '0; ev1_rs2_addr = '0;
    ev1_rs1_data = '0; ev1_rs2_data = '0;
    od0_enable = 1'b0; od0_rs1_addr = '0; od0_rs2_addr = '0;
    od0_rs1_data = '0; od0_rs2_data = '0;
    od1_enable = 1'b0; od1_rs1_addr = '0; od1_rs2_addr = '0;
    od1_rs1_data = '0; od1_rs2_data = '0;
    wb0_reg_write = 1'b0; wb0_rd_addr = '0; wb0_data = '0; wb0_pc = '0;
    wb1_reg_write = 1'b0; wb1_rd_addr = '0; wb1_data = '0; wb1_pc = '0;
  endtask

  task automatic check_u32(
    input string       name,
    input string       detail,
    input string       label,
    input logic [31:0] got,
    input logic [31:0] exp
  );
    bit pass;
    pass = (got === exp);
    tb_report_open(pass, name, detail);
    tb_field_u32(label, got, exp);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_u32_pair(
    input string       name,
    input string       detail,
    input string       label_a,
    input logic [31:0] got_a,
    input logic [31:0] exp_a,
    input string       label_b,
    input logic [31:0] got_b,
    input logic [31:0] exp_b
  );
    bit pass;
    pass = (got_a === exp_a) && (got_b === exp_b);
    tb_report_open(pass, name, detail);
    tb_field_u32(label_a, got_a, exp_a);
    tb_field_u32(label_b, got_b, exp_b);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    clear_inputs();

    tb_banner("forward_unit_tb - WB wb0/wb1 bypass");

    ev0_enable   = 1'b1;
    ev0_rs1_addr  = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    ev0_rs2_addr  = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    #1;
    check_u32_pair("passthrough", "no hazard: operands unchanged",
                   "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA,
                   "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);

    clear_inputs();
    ev0_enable    = 1'b1;
    ev0_rs1_addr  = 5'd2;  ev0_rs1_data = 32'hDEAD_DEAD;
    ev0_rs2_addr  = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32_pair("wb0_hit", "WB0 x2 hit on rs1 only",
                   "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h1234_5678,
                   "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);

    clear_inputs();
    od1_enable    = 1'b1;
    od1_rs2_addr  = 5'd9;  od1_rs2_data = 32'hDEAD_DEAD;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd9;
    wb1_data = 32'hCAFE_F00D; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb1_hit_od1_rs2", "WB1 x9 hit on od1 rs2",
              "od1_rs2_data_fwd", od1_rs2_data_fwd, 32'hCAFE_F00D);

    clear_inputs();
    od0_enable    = 1'b1;
    od0_rs1_addr  = 5'd7;  od0_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd7;
    wb0_data = 32'h0000_00C0; wb0_pc = 32'h0000_0100;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd7;
    wb1_data = 32'h0000_00C1; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb_double_younger", "wb0/wb1 same rd: younger (wb1) wins",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C1);

    clear_inputs();
    ev0_enable    = 1'b0;
    ev0_rs1_addr  = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32("disabled_no_fwd", "ev0 disabled: WB hit ignored",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA);

    clear_inputs();
    ev1_enable     = 1'b1;
    ev1_rs1_addr   = 5'd5;  ev1_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write  = 1'b1; wb0_rd_addr = 5'd5;
    wb0_data = 32'h0000_0BAD; wb0_pc = 32'h0000_0100;
    wb1_reg_write  = 1'b1; wb1_rd_addr = 5'd5;
    wb1_data = 32'h0000_600D; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb1_over_wb0", "wb1 younger wpc wins on same rd",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_600D);

    clear_inputs();
    od0_enable     = 1'b1;
    od0_rs1_addr   = 5'd7;  od0_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write  = 1'b1; wb0_rd_addr = 5'd7;
    wb0_data = 32'h0000_00C0; wb0_pc = 32'h0000_0100;
    wb1_reg_write  = 1'b1; wb1_rd_addr = 5'd7;
    wb1_data = 32'h0000_00C1; wb1_pc = 32'h0000_0100;
    #1;
    check_u32("wb_pc_tie", "equal WB pc: tie goes to wb1",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C1);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "forward_unit_tb failed");
    $finish;
  end

endmodule
