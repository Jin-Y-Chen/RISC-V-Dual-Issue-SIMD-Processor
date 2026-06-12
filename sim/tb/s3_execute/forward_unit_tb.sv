`timescale 1ns / 1ps

// forward_unit_tb - WB->EX combinational forwarding (hit, age priority,
// disabled port) and I0->I1 same-cycle falling-edge forward / i1_stall.
module forward_unit_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;

  // Consumer operand ports
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

  // I0 producer
  logic        i0_reg_write;
  logic [4:0]  i0_rd_addr;
  logic        ev0_unit_done;
  logic [31:0] ev0_result;
  logic        od0_unit_done;
  logic [31:0] od0_result;

  // WB write ports
  logic        wb0_reg_write;
  logic [4:0]  wb0_rd_addr;
  logic [31:0] wb0_data;
  logic [31:0] wb0_pc;
  logic        wb1_reg_write;
  logic [4:0]  wb1_rd_addr;
  logic [31:0] wb1_data;
  logic [31:0] wb1_pc;

  // Outputs
  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;
  logic        i1_stall;

  int pass_cnt;
  int fail_cnt;

  forward_unit dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic clear_inputs;
    ev0_enable = 1'b0; ev0_rs1_addr = '0; ev0_rs2_addr = '0;
    ev0_rs1_data = '0; ev0_rs2_data = '0;
    ev1_enable = 1'b0; ev1_rs1_addr = '0; ev1_rs2_addr = '0;
    ev1_rs1_data = '0; ev1_rs2_data = '0;
    od0_enable = 1'b0; od0_rs1_addr = '0; od0_rs2_addr = '0;
    od0_rs1_data = '0; od0_rs2_data = '0;
    od1_enable = 1'b0; od1_rs1_addr = '0; od1_rs2_addr = '0;
    od1_rs1_data = '0; od1_rs2_data = '0;
    i0_reg_write = 1'b0; i0_rd_addr = '0;
    ev0_unit_done = 1'b0; ev0_result = '0;
    od0_unit_done = 1'b0; od0_result = '0;
    wb0_reg_write = 1'b0; wb0_rd_addr = '0; wb0_data = '0; wb0_pc = '0;
    wb1_reg_write = 1'b0; wb1_rd_addr = '0; wb1_data = '0; wb1_pc = '0;
  endtask

  // Idle cycle so the negedge latch clears any override left by the last test,
  // then line up on a fresh posedge.
  task automatic next_test;
    clear_inputs();
    @(posedge clk);
    @(posedge clk);
    #1step;
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

  task automatic check_bit(
    input string name,
    input string detail,
    input string label,
    input logic  got,
    input logic  exp
  );
    bit pass;
    pass = (got === exp);
    tb_report_open(pass, name, detail);
    tb_field_bit(label, got, exp);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("forward_unit_tb - WB->EX forwarding and I0->I1 half-cycle forward");

    clear_inputs();
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1step;

    // --- 1. No hazard: operands pass through unchanged ---
    ev0_enable   = 1'b1;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    ev0_rs2_addr = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    #1;
    check_u32("passthrough_rs1", "no WB hit: ev0 rs1 unchanged",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA);
    check_u32("passthrough_rs2", "no WB hit: ev0 rs2 unchanged",
              "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);
    check_bit("passthrough_stall", "no RAW: i1_stall low",
              "i1_stall", i1_stall, 1'b0);
    next_test();

    // --- 2. WB0 hit replaces only the matching read port ---
    ev0_enable   = 1'b1;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'hDEAD_DEAD;  // stale GPR read
    ev0_rs2_addr = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32("wb0_hit_rs1", "WB0 x2 hit: ev0 rs1 takes wb0_data",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h1234_5678);
    check_u32("wb0_miss_rs2", "WB0 x2 hit: ev0 rs2 (x3) unaffected",
              "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);
    next_test();

    // --- 3. WB1 hit on an odd-copy read port ---
    od1_enable   = 1'b1;
    od1_rs1_addr = 5'd4;  od1_rs1_data = 32'h0000_0044;
    od1_rs2_addr = 5'd9;  od1_rs2_data = 32'hDEAD_DEAD;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd9;
    wb1_data = 32'hCAFE_F00D; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb1_hit_od1_rs2", "WB1 x9 hit: od1 rs2 takes wb1_data",
              "od1_rs2_data_fwd", od1_rs2_data_fwd, 32'hCAFE_F00D);
    next_test();

    // --- 4. Both WB ports write same rd: younger pc wins ---
    od0_enable   = 1'b1;
    od0_rs1_addr = 5'd7;  od0_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd7;
    wb0_data = 32'h0000_00C0; wb0_pc = 32'h0000_0100;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd7;
    wb1_data = 32'h0000_00C1; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb_double_younger", "wb0/wb1 same rd: younger (wb1) wins",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C1);
    // Swap ages: wb0 is now younger
    wb0_pc = 32'h0000_0104;
    wb1_pc = 32'h0000_0100;
    #1;
    check_u32("wb_double_swapped", "ages swapped: younger (wb0) wins",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C0);
    next_test();

    // --- 5. Disabled consumer: WB hit ignored ---
    ev0_enable   = 1'b0;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32("disabled_no_fwd", "ev0 disabled: rs1 passes through",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA);
    next_test();

    // --- 6. I0->I1 RAW, producer done: override after the falling edge ---
    // I0 = ADD x5,... in ev0 (done in first half); I1 = ev1 reads x5.
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd5;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_55AA;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd5;  ev1_rs1_data = 32'hDEAD_DEAD;  // stale GPR read
    ev1_rs2_addr  = 5'd6;  ev1_rs2_data = 32'h0000_0066;
    #1;
    check_u32("i0i1_first_half", "before negedge: ev1 rs1 still stale",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'hDEAD_DEAD);
    check_bit("i0i1_no_stall", "producer done: no replay needed",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("i0i1_second_half", "after negedge: ev1 rs1 takes ev0_result",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_55AA);
    check_u32("i0i1_rs2_intact", "non-RAW port (x6) unaffected",
              "ev1_rs2_data_fwd", ev1_rs2_data_fwd, 32'h0000_0066);
    next_test();

    // --- 7. Odd producer (JAL link) forwards to od1 consumer ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd1;
    od0_unit_done = 1'b1;  od0_result = 32'h0000_1234;   // link_pc
    od1_enable    = 1'b1;
    od1_rs2_addr  = 5'd1;  od1_rs2_data = 32'hDEAD_DEAD;
    @(negedge clk);
    #1step;
    check_u32("od_producer_fwd", "od0 link_pc forwards to od1 rs2",
              "od1_rs2_data_fwd", od1_rs2_data_fwd, 32'h0000_1234);
    next_test();

    // --- 8. RAW with producer not done (LW): i1_stall requests replay ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd8;            // LW x8: data in MEM
    od1_enable    = 1'b1;
    od1_rs1_addr  = 5'd8;  od1_rs1_data = 32'hDEAD_DEAD;
    #1;
    check_bit("lw_raw_stall", "RAW on LW result: i1_stall high",
              "i1_stall", i1_stall, 1'b1);
    @(negedge clk);
    #1step;
    check_u32("lw_raw_no_ovr", "not done: no override latched at negedge",
              "od1_rs1_data_fwd", od1_rs1_data_fwd, 32'hDEAD_DEAD);
    next_test();

    // --- 9. RAW on a different rd: no stall, no override ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd10;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_AAAA;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd11; ev1_rs1_data = 32'h0000_1111; // reads x11, not x10
    #1;
    check_bit("no_raw_no_stall", "rd/rs mismatch: i1_stall low",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("no_raw_no_ovr", "rd/rs mismatch: ev1 rs1 unchanged",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_1111);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "forward_unit_tb failed");
    $finish;
  end

endmodule
