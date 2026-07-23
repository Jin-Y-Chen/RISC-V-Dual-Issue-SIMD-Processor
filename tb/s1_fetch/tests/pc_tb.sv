`timescale 1ns / 1ps

`include "../../common/utils/tb_console.svh"

// pc_tb - exhaustive control sweep; reference = gm/pc_gm.sv.
// ctrl = {rst_n, enable, dispatch_stall, spec0_stall, spec1_stall, spec0_in, spec1_in}
module pc_tb;

  localparam int          CLK_PERIOD  = 10;
  localparam int          CTRL_BITS   = 7;
  localparam int          N_VECTORS   = (1 << CTRL_BITS);
  localparam logic [31:0] TB_RESET_PC = 32'h0000_0000;
  localparam logic [31:0] PC0_IN      = 32'h0000_1000;
  localparam logic [31:0] PC1_IN      = 32'h0000_1004;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        dispatch_stall;
  logic        spec0_stall;
  logic        spec1_stall;
  logic        spec0_in;
  logic        spec1_in;
  logic        spec0_out;
  logic        spec1_out;
  logic [31:0] pc0_in;
  logic [31:0] pc1_in;
  logic [31:0] pc0;
  logic [31:0] pc1;

  logic [31:0] ref_pc0;
  logic [31:0] ref_pc1;
  logic        ref_spec0_out;
  logic        ref_spec1_out;

  int pass_cnt;
  int fail_cnt;

  pc #(
    .RESET_PC(TB_RESET_PC)
  ) dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    .dispatch_stall  (dispatch_stall),
    .spec0_stall     (spec0_stall),
    .spec1_stall     (spec1_stall),
    .spec0_in        (spec0_in),
    .spec1_in        (spec1_in),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .pc0_out         (pc0),
    .pc1_out         (pc1),
    .spec0_out       (spec0_out),
    .spec1_out       (spec1_out)
  );

  pc_gm #(
    .RESET_PC(TB_RESET_PC)
  ) u_pc_gm (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable),
    .dispatch_stall (dispatch_stall),
    .spec0_stall    (spec0_stall),
    .spec1_stall    (spec1_stall),
    .spec0_in       (spec0_in),
    .spec1_in       (spec1_in),
    .pc0_in         (pc0_in),
    .pc1_in         (pc1_in),
    .pc0_out        (ref_pc0),
    .pc1_out        (ref_pc1),
    .spec0_out      (ref_spec0_out),
    .spec1_out      (ref_spec1_out)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk;

  task automatic check_vector(input logic [CTRL_BITS-1:0] ctrl);
    bit pass;

    @(posedge clk);
    rst_n          = 1'b0;
    enable         = 1'b0;
    dispatch_stall = 1'b0;
    spec0_stall    = 1'b0;
    spec1_stall    = 1'b0;
    spec0_in       = 1'b0;
    spec1_in       = 1'b0;
    pc0_in         = PC0_IN;
    pc1_in         = PC1_IN;
    #0;

    @(posedge clk);
    rst_n          = ctrl[6];
    enable         = ctrl[5];
    dispatch_stall = ctrl[4];
    spec0_stall    = ctrl[3];
    spec1_stall    = ctrl[2];
    spec0_in       = ctrl[1];
    spec1_in       = ctrl[0];
    #0;

    pass = (pc0 === ref_pc0) && (pc1 === ref_pc1)
        && (spec0_out === ref_spec0_out) && (spec1_out === ref_spec1_out);

    tb_report_open(pass, $sformatf("ctrl_%02x", ctrl),
                   $sformatf("ctrl=%0b", ctrl));
    tb_log_section("inputs");
    tb_field_in_bit("clk",            clk);
    tb_field_in_bit("rst_n",          rst_n);
    tb_field_in_bit("enable",         enable);
    tb_field_in_bit("dispatch_stall", dispatch_stall);
    tb_field_in_bit("spec0_stall",    spec0_stall);
    tb_field_in_bit("spec1_stall",    spec1_stall);
    tb_field_in_bit("spec0_in",       spec0_in);
    tb_field_in_bit("spec1_in",       spec1_in);
    tb_field_in_u32("pc0_in",         pc0_in);
    tb_field_in_u32("pc1_in",         pc1_in);
    $display("");
    tb_log_section("check");
    tb_field_bit("spec0_out", spec0_out, ref_spec0_out);
    tb_field_bit("spec1_out", spec1_out, ref_spec1_out);
    tb_field_u32("pc0_out",   pc0,       ref_pc0);
    tb_field_u32("pc1_out",   pc1,       ref_pc1);
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
