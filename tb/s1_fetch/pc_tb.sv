`timescale 1ns / 1ps

`include "../include/tb_console.svh"

// pc_tb — exhaustive control sweep; reference = gm/pc_gm.sv (64-entry LUT).
// Each vector applies inputs on posedge clk.
// No CASE_FILE — not file-driven; remove legacy CASE_FILE Vivado sim generic if set.
module pc_tb;

  localparam int          CLK_PERIOD  = 10;
  localparam int          CTRL_BITS   = 6;
  localparam int          N_VECTORS   = (1 << CTRL_BITS);
  localparam logic [31:0] TB_RESET_PC = 32'h0000_0000;
  localparam logic [31:0] PC0_IN      = 32'h0000_1000;
  localparam logic [31:0] PC1_IN      = 32'h0000_1004;

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

  pc_gm #(
    .RESET_PC(TB_RESET_PC)
  ) u_pc_gm (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .fetch_stall    (fetch_stall),
    .dispatch_stall (dispatch_stall),
    .mode           (mode),
    .spec0_en       (spec0_en),
    .pc0_in         (pc0_in),
    .pc1_in         (pc1_in),
    .pc0_out        (ref_pc0),
    .pc1_out        (ref_pc1),
    .is_spec        (ref_is_spec)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic check_vector(input logic [CTRL_BITS-1:0] ctrl);
    bit pass;

    @(posedge clk);
    rst_n          = 1'b0;
    enable         = 1'b0;
    fetch_stall    = 1'b0;
    dispatch_stall = 1'b0;
    mode           = 1'b0;
    spec0_en       = 1'b0;
    pc0_in         = PC0_IN;
    pc1_in         = PC1_IN;
    #0;

    @(posedge clk);
    rst_n          = ctrl[CTRL_BITS-1];
    enable         = ctrl[CTRL_BITS-2];
    fetch_stall    = ctrl[CTRL_BITS-3];
    dispatch_stall = ctrl[CTRL_BITS-4];
    mode           = ctrl[CTRL_BITS-5];
    spec0_en       = ctrl[0];
    #0;

    pass = (pc0 === ref_pc0) && (pc1 === ref_pc1) && (is_spec === ref_is_spec);

    tb_report_open(pass, $sformatf("ctrl_%02x", ctrl),
                   $sformatf("ctrl=%0b", ctrl));
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
    tb_field_bit("is_spec", is_spec, ref_is_spec);
    tb_field_u32("pc0_out", pc0, ref_pc0);
    tb_field_u32("pc1_out", pc1, ref_pc1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    int unsigned ctrl;

    pass_cnt = 0;
    fail_cnt = 0;
    tb_banner($sformatf("pc_tb: DUT vs pc_gm.sv (%0d vectors)", N_VECTORS));

    for (ctrl = 0; ctrl < N_VECTORS; ctrl++)
      check_vector(ctrl[CTRL_BITS-1:0]);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (pass_cnt + fail_cnt != N_VECTORS)
      $error("pc_tb: expected %0d vectors, ran %0d", N_VECTORS, pass_cnt + fail_cnt);
    else if (fail_cnt != 0)
      $error("pc_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
