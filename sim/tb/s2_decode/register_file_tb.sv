`timescale 1ns / 1ps

// register_file_tb — dual-issue GPR (project_outline §3, §8).
// Chained WB program; commit vs ID-read cycles; GPR_* != ADDI immediates in asm labels.
module register_file_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  // WB write data: must not equal small immediates in rf_detail() (avoids ADDI/RF confusion)
  localparam reg_t GPR_X5_INIT = 32'h0505_00A5;  // not 0xAA
  localparam reg_t GPR_X6_INIT = 32'h0606_00D6;  // not 0x11
  localparam reg_t GPR_X5_REW  = 32'h0505_00D7;  // not 0xBB
  localparam reg_t GPR_X6_REW  = 32'h0606_0A67;  // not 0x66
  localparam reg_t GPR_X12_WB  = 32'h1212_00AD;  // not 0x4D
  localparam reg_t GPR_X15_EV  = 32'h1515_00E1;  // not 0xEE
  localparam reg_t GPR_X15_OD  = 32'h1515_00F2;  // not 0xFF
  localparam reg_t GPR_X18_EV  = 32'h1818_00E8;  // not 0xEE
  localparam reg_t GPR_X18_OD  = 32'h1818_00F9;  // not 0xFF

  logic        clk;
  logic        rst_n;

  logic [4:0]  even_rs1_addr;
  logic [4:0]  even_rs2_addr;
  reg_t        even_rs1_data;
  reg_t        even_rs2_data;

  logic [4:0]  odd_rs1_addr;
  logic [4:0]  odd_rs2_addr;
  reg_t        odd_rs1_data;
  reg_t        odd_rs2_data;

  logic        even_wen;
  logic [4:0]  even_rd;
  reg_t        even_wdata;
  reg_t        even_wpc;

  logic        odd_wen;
  logic [4:0]  odd_rd;
  reg_t        odd_wdata;
  reg_t        odd_wpc;

  int pass_cnt;
  int fail_cnt;

  register_file dut (.*);

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_writes;
    even_wen   = 1'b0;
    odd_wen    = 1'b0;
    even_rd    = 5'd0;
    odd_rd     = 5'd0;
    even_wdata = '0;
    odd_wdata  = '0;
    even_wpc   = '0;
    odd_wpc    = '0;
  endtask

  task automatic set_reads(
    input logic [4:0] e_rs1,
    input logic [4:0] e_rs2,
    input logic [4:0] o_rs1,
    input logic [4:0] o_rs2
  );
    even_rs1_addr = e_rs1;
    even_rs2_addr = e_rs2;
    odd_rs1_addr  = o_rs1;
    odd_rs2_addr  = o_rs2;
    #1;
  endtask

  task automatic drive_writes(
    input logic        e_wen,
    input logic [4:0]  e_rd,
    input reg_t        e_wdata,
    input reg_t        e_wpc,
    input logic        o_wen,
    input logic [4:0]  o_rd,
    input reg_t        o_wdata,
    input reg_t        o_wpc
  );
    even_wen   = e_wen;
    even_rd    = e_rd;
    even_wdata = e_wdata;
    even_wpc   = e_wpc;
    odd_wen    = o_wen;
    odd_rd     = o_rd;
    odd_wdata  = o_wdata;
    odd_wpc    = o_wpc;
  endtask

  // One-cycle WB commit; GPR array carries into following tests.
  task automatic commit_wb(
    input logic        e_wen,
    input logic [4:0]  e_rd,
    input reg_t        e_wdata,
    input reg_t        e_wpc,
    input logic        o_wen,
    input logic [4:0]  o_rd,
    input reg_t        o_wdata,
    input reg_t        o_wpc
  );
    drive_writes(e_wen, e_rd, e_wdata, e_wpc, o_wen, o_rd, o_wdata, o_wpc);
    tick();
    clear_writes();
  endtask

  task automatic tb_field_xreg(input string label, input logic [4:0] got, input logic [4:0] exp);
    tb_field_line(label, $sformatf("x%0d", got), $sformatf("x%0d", exp));
  endtask

  task automatic check_rf(
    input string      name,
    input string      detail,
    input logic [4:0] exp_e_rs1_addr,
    input logic [4:0] exp_e_rs2_addr,
    input logic [4:0] exp_o_rs1_addr,
    input logic [4:0] exp_o_rs2_addr,
    input reg_t       exp_e_rs1_data,
    input reg_t       exp_e_rs2_data,
    input reg_t       exp_o_rs1_data,
    input reg_t       exp_o_rs2_data,
    input logic       exp_even_wen,
    input logic [4:0] exp_even_rd,
    input reg_t       exp_even_wdata,
    input reg_t       exp_even_wpc,
    input logic       exp_odd_wen,
    input logic [4:0] exp_odd_rd,
    input reg_t       exp_odd_wdata,
    input reg_t       exp_odd_wpc
  );
    bit pass;
    pass = (even_rs1_addr === exp_e_rs1_addr) && (even_rs2_addr === exp_e_rs2_addr) &&
           (odd_rs1_addr  === exp_o_rs1_addr)  && (odd_rs2_addr  === exp_o_rs2_addr)  &&
           (even_rs1_data === exp_e_rs1_data) && (even_rs2_data === exp_e_rs2_data) &&
           (odd_rs1_data  === exp_o_rs1_data)  && (odd_rs2_data  === exp_o_rs2_data)  &&
           (even_wen      === exp_even_wen)    && (even_rd       === exp_even_rd)    &&
           (even_wdata    === exp_even_wdata)  && (even_wpc      === exp_even_wpc)    &&
           (odd_wen       === exp_odd_wen)     && (odd_rd        === exp_odd_rd)     &&
           (odd_wdata     === exp_odd_wdata)   && (odd_wpc       === exp_odd_wpc);
    tb_report_open(pass, name, detail);
    $display("  --- read ports (ID) ---");
    tb_field_xreg("even_rs1_addr", even_rs1_addr, exp_e_rs1_addr);
    tb_field_u32 ("even_rs1_data", even_rs1_data, exp_e_rs1_data);
    tb_field_xreg("even_rs2_addr", even_rs2_addr, exp_e_rs2_addr);
    tb_field_u32 ("even_rs2_data", even_rs2_data, exp_e_rs2_data);
    tb_field_xreg("odd_rs1_addr",  odd_rs1_addr,  exp_o_rs1_addr);
    tb_field_u32 ("odd_rs1_data",  odd_rs1_data,  exp_o_rs1_data);
    tb_field_xreg("odd_rs2_addr",  odd_rs2_addr,  exp_o_rs2_addr);
    tb_field_u32 ("odd_rs2_data",  odd_rs2_data,  exp_o_rs2_data);
    $display("  --- write ports (WB) ---");
    tb_field_bit ("even_wen",      even_wen,      exp_even_wen);
    tb_field_xreg("even_rd",       even_rd,       exp_even_rd);
    tb_field_u32 ("even_wdata",    even_wdata,    exp_even_wdata);
    tb_field_u32 ("even_wpc",      even_wpc,      exp_even_wpc);
    tb_field_bit ("odd_wen",       odd_wen,       exp_odd_wen);
    tb_field_xreg("odd_rd",        odd_rd,        exp_odd_rd);
    tb_field_u32 ("odd_wdata",     odd_wdata,     exp_odd_wdata);
    tb_field_u32 ("odd_wpc",       odd_wpc,       exp_odd_wpc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  function automatic string rf_detail(input string asm);
    return asm;
  endfunction

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    even_rs1_addr = 5'd0;
    even_rs2_addr = 5'd0;
    odd_rs1_addr  = 5'd0;
    odd_rs2_addr  = 5'd0;
    clear_writes();

    rst_n = 1'b0;
    repeat (2) tick();
    rst_n = 1'b1;
    tick();

    tb_banner("register_file_tb - dual-issue GPR (chained GPR state)");

    // GPR state: all zero
    set_reads(5'd1, 5'd2, 5'd3, 5'd4);
    check_rf("after_reset",
      rf_detail("ADD x3,x1,x2 | SW x4,0(x3)"),
      5'd1, 5'd2, 5'd3, 5'd4,
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state: x6/x5 hold ALU/WB results (not raw ADDI immediates 0x11 / 0xAA)
    drive_writes(1'b1, 5'd6, GPR_X6_INIT, 32'h0FFC,
                 1'b1, 5'd5, GPR_X5_INIT, 32'h1000);
    set_reads(5'd5, 5'd6, 5'd5, 5'd0);
    check_rf("dual_addi_commit_x6_x5",
      rf_detail("ADDI x6,x0,0x11 | ADDI x5,x0,0xAA"),
      5'd5, 5'd6, 5'd5, 5'd0,
      GPR_X5_INIT, GPR_X6_INIT, GPR_X5_INIT, 32'd0,
      1'b1, 5'd6, GPR_X6_INIT, 32'h0FFC,
      1'b1, 5'd5, GPR_X5_INIT, 32'h1000);
    tick();
    clear_writes();
    // Next cycle: dependent ADD/LW in ID read committed GPRs (WB idle)
    set_reads(5'd5, 5'd6, 5'd5, 5'd0);
    check_rf("read_add_lw_after_addi",
      rf_detail("ADD x10,x5,x6 | LW x11,0(x5)"),
      5'd5, 5'd6, 5'd5, 5'd0,
      GPR_X5_INIT, GPR_X6_INIT, GPR_X5_INIT, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state: + x3=0xA3B1C3D3, x7=0xB7B2C7E7 (x5,x6 unchanged)
    drive_writes(1'b1, 5'd3, 32'hA3B1_C3D3, 32'h1004,
                 1'b1, 5'd7, 32'hB7B2_C7E7, 32'h1008);
    set_reads(5'd3, 5'd7, 5'd7, 5'd0);
    check_rf("dual_wb_commit",
      rf_detail("ADDI x3,x0,1 | LW x7,0(x8)"),
      5'd3, 5'd7, 5'd7, 5'd0,
      32'hA3B1_C3D3, 32'hB7B2_C7E7, 32'hB7B2_C7E7, 32'd0,
      1'b1, 5'd3, 32'hA3B1_C3D3, 32'h1004,
      1'b1, 5'd7, 32'hB7B2_C7E7, 32'h1008);
    tick();
    clear_writes();
    set_reads(5'd3, 5'd7, 5'd7, 5'd0);
    check_rf("read_after_dual_wb_x3_x7",
      rf_detail("ADD x9,x3,x7 | LW x10,0(x7)"),
      5'd3, 5'd7, 5'd7, 5'd0,
      32'hA3B1_C3D3, 32'hB7B2_C7E7, 32'hB7B2_C7E7, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state unchanged: x0 always 0; x5/x6 still from first commits
    set_reads(5'd0, 5'd0, 5'd5, 5'd6);
    check_rf("read_x0_and_chain",
      rf_detail("ADD x8,x0,x0 | LW x11,0(x5)"),
      5'd0, 5'd0, 5'd5, 5'd6,
      32'd0, 32'd0, GPR_X5_INIT, GPR_X6_INIT,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state: x5 rewritten (WB result != ADDI imm 0xBB); x6 unchanged
    commit_wb(1'b1, 5'd0, 32'hDEAD_BEEF, 32'h2000,
              1'b1, 5'd5, GPR_X5_REW, 32'h2004);
    set_reads(5'd5, 5'd6, 5'd0, 5'd0);
    check_rf("wr_x0_ignore",
      rf_detail("ADD x0,x1,x2 | ADDI x5,x0,0xBB | LW x10,0(x5)"),
      5'd5, 5'd6, 5'd0, 5'd0,
      GPR_X5_REW, GPR_X6_INIT, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state: + x8=0x2222_2222 (odd wpc wins over even on same rd)
    drive_writes(1'b1, 5'd8, 32'h1111_1111, 32'h3000,
                 1'b1, 5'd8, 32'h2222_2222, 32'h3004);
    tick();
    set_reads(5'd8, 5'd0, 5'd8, 5'd0);
    check_rf("merge_odd_wins",
      rf_detail("ADD x8,x1,x2 | LW x8,0(x13) | ADD x14,x8,x0 | LW x15,0(x8)"),
      5'd8, 5'd0, 5'd8, 5'd0,
      32'h2222_2222, 32'd0, 32'h2222_2222, 32'd0,
      1'b1, 5'd8, 32'h1111_1111, 32'h3000,
      1'b1, 5'd8, 32'h2222_2222, 32'h3004);
    clear_writes();

    // GPR state: + x9=0xAAAA_AAAA (even wpc wins)
    drive_writes(1'b1, 5'd9, 32'hAAAA_AAAA, 32'h4008,
                 1'b1, 5'd9, 32'hBBBB_BBBB, 32'h4004);
    tick();
    set_reads(5'd9, 5'd0, 5'd9, 5'd0);
    check_rf("merge_even_wins",
      rf_detail("ADD x9,x1,x2 | LW x9,0(x10) | ADD x11,x9,x0 | LW x12,0(x9)"),
      5'd9, 5'd0, 5'd9, 5'd0,
      32'hAAAA_AAAA, 32'd0, 32'hAAAA_AAAA, 32'd0,
      1'b1, 5'd9, 32'hAAAA_AAAA, 32'h4008,
      1'b1, 5'd9, 32'hBBBB_BBBB, 32'h4004);
    clear_writes();

    // GPR state: + x12=0x4D (same-cycle bypass on read)
    drive_writes(1'b1, 5'd12, GPR_X12_WB, 32'h5000,
                 1'b0, 5'd0, 32'd0, 32'd0);
    set_reads(5'd12, 5'd0, 5'd0, 5'd0);
    check_rf("bypass_even",
      rf_detail("ADDI x12,x0,0x4D | ADD x13,x12,x0"),
      5'd12, 5'd0, 5'd0, 5'd0,
      GPR_X12_WB, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd12, GPR_X12_WB, 32'h5000,
      1'b0, 5'd0, 32'd0, 32'd0);
    tick();
    clear_writes();
    set_reads(5'd12, 5'd0, 5'd0, 5'd0);
    check_rf("bypass_even_hold",
      rf_detail("ADD x13,x12,x0"),
      5'd12, 5'd0, 5'd0, 5'd0,
      GPR_X12_WB, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    // GPR state: + x15=0xFF (odd bypass wins on same rd)
    drive_writes(1'b1, 5'd15, GPR_X15_EV, 32'h6000,
                 1'b1, 5'd15, GPR_X15_OD, 32'h6004);
    set_reads(5'd15, 5'd0, 5'd15, 5'd0);
    check_rf("bypass_odd_wins",
      rf_detail("ADDI x15,x0,0xEE | LW x15,0(x16) | ADD x17,x15,x0 | LW x18,0(x15)"),
      5'd15, 5'd0, 5'd15, 5'd0,
      GPR_X15_OD, 32'd0, GPR_X15_OD, 32'd0,
      1'b1, 5'd15, GPR_X15_EV, 32'h6000,
      1'b1, 5'd15, GPR_X15_OD, 32'h6004);
    tick();
    clear_writes();

    // GPR state: x6 overwritten (WB != imm 0x66); x5 still GPR_X5_REW
    drive_writes(1'b1, 5'd6, GPR_X6_REW, 32'h8000,
                 1'b0, 5'd0, 32'd0, 32'd0);
    tick();
    set_reads(5'd6, 5'd6, 5'd6, 5'd6);
    check_rf("dual_read_same_rd",
      rf_detail("ADDI x6,x0,0x66 | ADD x7,x6,x6 | SW x8,0(x6)"),
      5'd6, 5'd6, 5'd6, 5'd6,
      GPR_X6_REW, GPR_X6_REW, GPR_X6_REW, GPR_X6_REW,
      1'b1, 5'd6, GPR_X6_REW, 32'h8000,
      1'b0, 5'd0, 32'd0, 32'd0);
    clear_writes();
    set_reads(5'd5, 5'd6, 5'd3, 5'd7);
    check_rf("read_chain_x5_x6_x3_x7",
      rf_detail("ADD x10,x5,x6 | LW x11,0(x5) | ADD x9,x3,x7"),
      5'd5, 5'd6, 5'd3, 5'd7,
      GPR_X5_REW, GPR_X6_REW, 32'hA3B1_C3D3, 32'hB7B2_C7E7,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    drive_writes(1'b1, 5'd17, 32'hAAAA_0001, 32'h9008,
                 1'b1, 5'd17, 32'hBBBB_0002, 32'h9004);
    set_reads(5'd17, 5'd17, 5'd17, 5'd17);
    check_rf("bypass_merge_even_wins",
      rf_detail("ADD x17,x1,x2 | LW x17,0(x3) | ADD x19,x17,x17 | SW x20,0(x17)"),
      5'd17, 5'd17, 5'd17, 5'd17,
      32'hAAAA_0001, 32'hAAAA_0001, 32'hAAAA_0001, 32'hAAAA_0001,
      1'b1, 5'd17, 32'hAAAA_0001, 32'h9008,
      1'b1, 5'd17, 32'hBBBB_0002, 32'h9004);
    tick();
    clear_writes();
    set_reads(5'd17, 5'd0, 5'd17, 5'd0);
    check_rf("bypass_merge_even_hold",
      rf_detail("ADD x19,x17,x0 | LW x20,0(x17)"),
      5'd17, 5'd0, 5'd17, 5'd0,
      32'hAAAA_0001, 32'd0, 32'hAAAA_0001, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    drive_writes(1'b1, 5'd18, GPR_X18_EV, 32'hA000,
                 1'b1, 5'd18, GPR_X18_OD, 32'hA004);
    set_reads(5'd18, 5'd18, 5'd18, 5'd18);
    check_rf("bypass_four_ports_one_rd",
      rf_detail("ADDI x18,x0,0xEE | LW x18,0(x19) | ADD x20,x18,x18 | SW x21,0(x18)"),
      5'd18, 5'd18, 5'd18, 5'd18,
      GPR_X18_OD, GPR_X18_OD, GPR_X18_OD, GPR_X18_OD,
      1'b1, 5'd18, GPR_X18_EV, 32'hA000,
      1'b1, 5'd18, GPR_X18_OD, 32'hA004);
    tick();
    clear_writes();

    drive_writes(1'b1, 5'd11, 32'h1234_5678, 32'hB000,
                 1'b0, 5'd0, 32'd0, 32'd0);
    set_reads(5'd0, 5'd0, 5'd11, 5'd11);
    check_rf("bypass_raw_i0_odd_rs",
      rf_detail("ADD x11,x1,x2 | SW x12,0(x11)"),
      5'd0, 5'd0, 5'd11, 5'd11,
      32'd0, 32'd0, 32'h1234_5678, 32'h1234_5678,
      1'b1, 5'd11, 32'h1234_5678, 32'hB000,
      1'b0, 5'd0, 32'd0, 32'd0);
    set_reads(5'd11, 5'd11, 5'd11, 5'd11);
    check_rf("bypass_raw_i0_all_ports",
      rf_detail("ADD x11,x1,x2 | ADD x12,x11,x11 | SW x13,0(x11)"),
      5'd11, 5'd11, 5'd11, 5'd11,
      32'h1234_5678, 32'h1234_5678, 32'h1234_5678, 32'h1234_5678,
      1'b1, 5'd11, 32'h1234_5678, 32'hB000,
      1'b0, 5'd0, 32'd0, 32'd0);
    tick();
    clear_writes();

    // GPR state: + x20,x21; snapshot still sees earlier chain regs on other ports
    commit_wb(1'b1, 5'd20, 32'hD20E_A020, 32'h7000,
              1'b1, 5'd21, 32'hD21E_B021, 32'h7004);
    set_reads(5'd20, 5'd21, 5'd5, 5'd6);
    check_rf("four_ports_and_chain",
      rf_detail("ADD x23,x20,x21 | LW x24,0(x20) | ADD x10,x5,x6"),
      5'd20, 5'd21, 5'd5, 5'd6,
      32'hD20E_A020, 32'hD21E_B021, GPR_X5_REW, GPR_X6_REW,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    set_reads(5'd11, 5'd12, 5'd9, 5'd0);
    check_rf("read_final_chain",
      rf_detail("ADD x12,x11,x12 | LW x13,0(x8) | ADD x14,x9,x0"),
      5'd11, 5'd12, 5'd9, 5'd0,
      32'h1234_5678, GPR_X12_WB, 32'hAAAA_AAAA, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "register_file_tb failed");
    $finish;
  end

endmodule
