`timescale 1ns / 1ps

// pc_selector_tb — exhaustive 5-bit control sweep; reference = gm/pc_selector_gm.sv.
module pc_selector_tb;

  localparam int CTRL_BITS = 5;
  localparam int N_VECTORS = 1 << CTRL_BITS;

  localparam logic [31:0] PC0_IN = 32'h0000_1000;
  localparam logic [31:0] PC1_IN = 32'h0000_1004;
  localparam logic [31:0] TGT0   = 32'h0000_2000;
  localparam logic [31:0] TGT1   = 32'h0000_3000;
  localparam logic [31:0] EXEC0 = 32'h0000_4000;
  localparam logic [31:0] EXEC1 = 32'h0000_5000;

  logic        is_spec;
  logic        i0_pred_taken;
  logic        i1_pred_taken;
  logic        i0_brch_recover;
  logic        i1_brch_recover;
  logic [31:0] pc0_in;
  logic [31:0] pc1_in;
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;
  logic [31:0] i0_pc_execute;
  logic [31:0] i1_pc_execute;
  logic        stall;
  logic        mode;
  logic        spec0_en;
  logic [31:0] pc0_out;
  logic [31:0] pc1_out;

  logic        ref_stall;
  logic        ref_mode;
  logic        ref_spec0_en;
  logic [31:0] ref_pc0_out;
  logic [31:0] ref_pc1_out;

  int pass_cnt;
  int fail_cnt;

  pc_selector dut (
    .is_spec         (is_spec),
    .i0_pred_taken   (i0_pred_taken),
    .i1_pred_taken   (i1_pred_taken),
    .i0_brch_recover (i0_brch_recover),
    .i1_brch_recover (i1_brch_recover),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target),
    .i0_pc_execute   (i0_pc_execute),
    .i1_pc_execute   (i1_pc_execute),
    .stall           (stall),
    .mode            (mode),
    .spec0_en        (spec0_en),
    .pc0_out         (pc0_out),
    .pc1_out         (pc1_out)
  );

  pc_selector_gm u_pc_selector_gm (
    .is_spec         (is_spec),
    .i0_pred_taken   (i0_pred_taken),
    .i1_pred_taken   (i1_pred_taken),
    .i0_brch_recover (i0_brch_recover),
    .i1_brch_recover (i1_brch_recover),
    .pc0_in          (pc0_in),
    .pc1_in          (pc1_in),
    .i0_pc_target    (i0_pc_target),
    .i1_pc_target    (i1_pc_target),
    .i0_pc_execute   (i0_pc_execute),
    .i1_pc_execute   (i1_pc_execute),
    .stall           (ref_stall),
    .mode            (ref_mode),
    .spec0_en        (ref_spec0_en),
    .pc0_out         (ref_pc0_out),
    .pc1_out         (ref_pc1_out)
  );

  `include "tb_console.svh"

  task automatic check_vector(input int unsigned ctrl);
    bit pass;
    string detail;

    is_spec         = ctrl[4];
    i0_pred_taken   = ctrl[3];
    i1_pred_taken   = ctrl[2];
    i0_brch_recover = ctrl[1];
    i1_brch_recover = ctrl[0];
    pc0_in          = PC0_IN;
    pc1_in          = PC1_IN;
    i0_pc_target    = TGT0;
    i1_pc_target    = TGT1;
    i0_pc_execute   = EXEC0;
    i1_pc_execute   = EXEC1;
    #0;

    pass = (stall === ref_stall) && (mode === ref_mode) && (spec0_en === ref_spec0_en)
        && (pc0_out === ref_pc0_out) && (pc1_out === ref_pc1_out);

    detail = $sformatf("ctrl=%05b", ctrl[4:0]);
    tb_report_open(pass, $sformatf("ctrl_%02x", ctrl), detail);
    tb_field_bit("stall",    stall,    ref_stall);
    tb_field_bit("mode",     mode,     ref_mode);
    tb_field_bit("spec0_en", spec0_en, ref_spec0_en);
    tb_field_u32("pc0_out",  pc0_out,  ref_pc0_out);
    tb_field_u32("pc1_out",  pc1_out,  ref_pc1_out);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    int unsigned ctrl;

    pass_cnt = 0;
    fail_cnt = 0;
    tb_banner("pc_selector_tb — DUT vs pc_selector_gm.sv (32 vectors)");

    for (ctrl = 0; ctrl < N_VECTORS; ctrl++)
      check_vector(ctrl);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "pc_selector_tb failed");
    $finish;
  end

endmodule
