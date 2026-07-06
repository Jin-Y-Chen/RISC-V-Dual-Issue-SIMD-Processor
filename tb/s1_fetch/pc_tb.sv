`timescale 1ns / 1ps

// pc_tb — drives inputs from sim.log scenario list; exp from pc.sv reference model.
module pc_tb;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam logic [31:0] TB_RESET_PC = 32'h0000_0000;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        fetch_stall;
  logic        dispatch_stall;
  logic        mode;
  logic        spec0_en;
  logic        is_spec;
  logic [31:0] pc0_in;
  logic [31:0] pc1_in;
  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] ref_pc0;
  logic [31:0] ref_pc1;
  logic        ref_is_spec;

  int pass_cnt;
  int fail_cnt;

  pc #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .fetch_stall     (fetch_stall),
    .dispatch_stall  (dispatch_stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .is_spec         (is_spec),
    .pc0_out         (pc0),
    .pc1_out         (pc1)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic tick;
    @(negedge clk);
  endtask

  task automatic drive(
    input logic        enable_v,
    input logic        fetch_stall_v,
    input logic        dispatch_stall_v,
    input logic        mode_v,
    input logic        spec0_en_v,
    input logic [31:0] pc0_in_v,
    input logic [31:0] pc1_in_v
  );
    enable         = enable_v;
    fetch_stall    = fetch_stall_v;
    dispatch_stall = dispatch_stall_v;
    mode           = mode_v;
    spec0_en       = spec0_en_v;
    pc0_in         = pc0_in_v;
    pc1_in         = pc1_in_v;
  endtask

  task automatic check_state(
    input string name,
    input string detail
  );
    bit pass;
    logic pc_apply;
    logic exp_is_spec;
    logic [31:0] exp_pc0_out;
    logic [31:0] exp_pc1_out;

    pc_apply = rst_n && enable && !fetch_stall && !dispatch_stall;

    if (!rst_n)
      exp_is_spec = 1'b0;
    else if (enable && !fetch_stall && !dispatch_stall)
      exp_is_spec = spec0_en;
    else
      exp_is_spec = ref_is_spec;

    if (pc_apply) begin
      exp_pc0_out = {pc0_in[31:2], 2'b00} + (mode ? 32'd4 : 32'd8);
      exp_pc1_out = {pc1_in[31:2], 2'b00} + (mode ? 32'd4 : 32'd8);
    end else if (!rst_n) begin
      exp_pc0_out = TB_RESET_PC;
      exp_pc1_out = TB_RESET_PC + 32'd4;
    end else begin
      exp_pc0_out = ref_pc0;
      exp_pc1_out = ref_pc1;
    end

    pass = (pc0 === exp_pc0_out) && (pc1 === exp_pc1_out) && (is_spec === exp_is_spec);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("rst_n",          rst_n);
    tb_field_in_bit("enable",         enable);
    tb_field_in_bit("fetch_stall",    fetch_stall);
    tb_field_in_bit("dispatch_stall", dispatch_stall);
    tb_field_in_bit("mode",           mode);
    tb_field_in_bit("spec0_en",       spec0_en);
    tb_field_in_u32("pc0_in",         pc0_in);
    tb_field_in_u32("pc1_in",         pc1_in);
    $display("");
    tb_log_section("check");
    tb_field_bit("is_spec", is_spec, exp_is_spec);
    tb_field_u32("pc0_out", pc0, exp_pc0_out);
    tb_field_u32("pc1_out", pc1, exp_pc1_out);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
    // Advance independent reference state from inputs only (not DUT outputs).
    ref_pc0     = exp_pc0_out;
    ref_pc1     = exp_pc1_out;
    ref_is_spec = exp_is_spec;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    ref_pc0     = TB_RESET_PC;
    ref_pc1     = TB_RESET_PC + 32'd4;
    ref_is_spec = 1'b0;

    tb_banner("pc_tb — control coverage");

    // --- reset ---
    rst_n = 1'b0;
    drive(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_0000, 32'h0000_0000);
    tick();
    check_state("reset", "RESET_PC pair Behavior");
    rst_n = 1'b1;

    // --- mode(0) ---
    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_0000, 32'h0000_0004);
    tick();
    check_state("mode(0)_default",
                "mode=0 +8/+8, dual issue without speculation (spec0_en=0)");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_0008, 32'h0000_000C);
    tick();
    check_state("mode(0)_loopback",
                "mode=0 +8/+8, loopback without speculation (spec0_en=0)");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 32'h0000_1008, 32'h0000_100C);
    tick();
    check_state("mode(0)_spec0_en(1)",
                "mode=0 +8/+8, dual issue with speculation (spec0_en=1)");

    // --- mode(1) ---
    drive(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 32'h0000_2000, 32'h0000_1014);
    tick();
    check_state("mode(1)_spec0_en(0)",
                "mode=1 +4/+4, dual issue without speculation (spec0_en=0)");

    drive(1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 32'h0000_2004, 32'h0000_1008);
    tick();
    check_state("mode(1)_spec0_en(1)",
                "mode=1 +4/+4, dual issue with speculation (spec0_en=1)");

    // --- alignment ---
    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2003, 32'h0000_2007);
    tick();
    check_state("mode(0)_align",
                "mode=0, +8/+8, check for alignment of pc0 and pc1");

    drive(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 32'h0000_2005, 32'h0000_1019);
    tick();
    check_state("mode(1)_align",
                "mode=1, +4/+4, check for alignment of pc0 and pc1");

    // --- mode(0) cycles ---
    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2008, 32'h0000_200C);
    tick();
    check_state("mode(0)_c0", "mode=0 cycle0: +8/+8");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2010, 32'h0000_1024);
    tick();
    check_state("mode(0)_c1", "mode=0 cycle1: +8/+8");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2018, 32'h0000_102C);
    tick();
    check_state("mode(0)_c2", "mode=0 cycle2: +8/+8");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2020, 32'h0000_1034);
    tick();
    check_state("mode(0)_c3", "mode=0 cycle3: +8/+8");

    // --- mode(1) cycles ---
    drive(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 32'h0000_2008, 32'h0000_101C);
    tick();
    check_state("mode(1)_c0", "mode=1 cycle0: +4/+4");

    drive(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 32'h0000_200C, 32'h0000_1020);
    tick();
    check_state("mode(1)_c1", "mode=1 cycle1: +4/+4");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2010, 32'h0000_1024);
    tick();
    check_state("mode(1)_c2", "mode=1 cycle2: +4/+4");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_2014, 32'h0000_1028);
    tick();
    check_state("mode(1)_c3", "mode=1 cycle3: +4/+4");

    // --- stall while speculating ---
    drive(1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 32'h0000_2008, 32'h0000_200C);
    tick();
    check_state("mode(0)_fetch_stall",
                "mode=0, +8/+8, prevent speculation on speculation on same path");

    drive(1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 32'h0000_2008, 32'h0000_101C);
    tick();
    check_state("mode(1)_fetch_stall",
                "mode=1, +4/+4, prevent speculation on speculation on either path");

    // --- fetch_stall ---
    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_5000, 32'h0000_5004);
    tick();
    check_state("pre_fetch_stall", "baseline before fetch_stall");

    drive(1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 32'h0000_6000, 32'h0000_6004);
    tick();
    check_state("fetch_stall_hold",
                "During fetch_stall, PC does not advance (mode ignored)");

    drive(1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 32'h0000_6000, 32'h0000_6004);
    tick();
    check_state("fetch_stall_is_spec",
                "During fetch_stall, is_spec does not update");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_5008, 32'h0000_500C);
    tick();
    check_state("fetch_stall_release", "release fetch_stall resumes +8/+8");

    // --- dispatch_stall ---
    drive(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 32'h0000_2008, 32'h0000_200C);
    tick();
    check_state("mode(0)_dispatch_stall",
                "mode=0, +8/+8, dispatch buffer full, stall required");

    drive(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 32'h0000_2008, 32'h0000_101C);
    tick();
    check_state("mode(1)_dispatch_stall",
                "mode=1, +4/+4, dispatch buffer full, stall required");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_5000, 32'h0000_5004);
    tick();
    check_state("pre_dispatch_stall", "baseline before dispatch_stall");

    drive(1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 32'h0000_7000, 32'h0000_7004);
    tick();
    check_state("dispatch_stall_hold",
                "During dispatch_stall, PC does not advance (mode ignored)");

    drive(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 32'h0000_7000, 32'h0000_7004);
    tick();
    check_state("dispatch_stall_is_spec",
                "During dispatch_stall, is_spec does not update");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_5010, 32'h0000_5014);
    tick();
    check_state("dispatch_stall_release", "release dispatch_stall resumes");

    // --- both stalls ---
    drive(1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 32'h0000_8000, 32'h0000_8004);
    tick();
    check_state("both_stall_hold", "either stall bit holds PC");

    drive(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0000_5018, 32'h0000_501C);
    tick();
    check_state("both_stall_release", "clear both stalls resumes");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_tb failed");
    $finish;
  end

endmodule
