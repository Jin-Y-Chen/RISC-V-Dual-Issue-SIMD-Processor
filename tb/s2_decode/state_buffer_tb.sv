`timescale 1ns / 1ps

`include "../include/tb_console.svh"

// state_buffer_tb — DUT vs gm/state_buffer_gm.sv (bank replica + WB bypass).
module state_buffer_tb;

  localparam logic [31:0] PC0   = 32'h0000_1000;
  localparam logic [31:0] PC1   = 32'h0000_1004;
  localparam logic [31:0] BR_PC = 32'h0000_2000;

  logic [31:0] i0_pc, i1_pc;
  logic        i0_brch_en, i1_brch_en;
  logic        i0_valid_wb, i1_valid_wb;
  logic [31:0] i0_pc_wb, i1_pc_wb;
  logic [1:0]  i0_target_state_wb, i1_target_state_wb;
  logic [1:0]  i0_target_state, i1_target_state;
  logic [1:0]  ref_i0_target_state, ref_i1_target_state;
  logic        clk, rst_n;

  int pass_cnt;
  int fail_cnt;

  state_buffer #(
    .INDEX_W(6)
  ) dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .i0_pc              (i0_pc),
    .i1_pc              (i1_pc),
    .i0_brch_en         (i0_brch_en),
    .i1_brch_en         (i1_brch_en),
    .i0_valid_wb        (i0_valid_wb),
    .i1_valid_wb        (i1_valid_wb),
    .i0_pc_wb           (i0_pc_wb),
    .i1_pc_wb           (i1_pc_wb),
    .i0_target_state_wb (i0_target_state_wb),
    .i1_target_state_wb (i1_target_state_wb),
    .i0_target_state    (i0_target_state),
    .i1_target_state    (i1_target_state)
  );

  state_buffer_gm #(
    .INDEX_W(6)
  ) u_state_buffer_gm (
    .clk                (clk),
    .rst_n              (rst_n),
    .i0_pc              (i0_pc),
    .i1_pc              (i1_pc),
    .i0_brch_en         (i0_brch_en),
    .i1_brch_en         (i1_brch_en),
    .i0_valid_wb        (i0_valid_wb),
    .i1_valid_wb        (i1_valid_wb),
    .i0_pc_wb           (i0_pc_wb),
    .i1_pc_wb           (i1_pc_wb),
    .i0_target_state_wb (i0_target_state_wb),
    .i1_target_state_wb (i1_target_state_wb),
    .i0_target_state    (ref_i0_target_state),
    .i1_target_state    (ref_i1_target_state)
  );

  // Stimulus helper — same transition table as rtl/s5_memory/core/state_lookup.sv.
  function automatic logic [1:0] state_lut_next(
    input logic [1:0] state,
    input logic       taken
  );
    unique case ({state, taken})
      3'b000: state_lut_next = 2'b00;
      3'b001: state_lut_next = 2'b01;
      3'b010: state_lut_next = 2'b00;
      3'b011: state_lut_next = 2'b11;
      3'b100: state_lut_next = 2'b00;
      3'b101: state_lut_next = 2'b11;
      3'b110: state_lut_next = 2'b10;
      3'b111: state_lut_next = 2'b11;
      default: state_lut_next = 2'b01;
    endcase
  endfunction

  task automatic check_states(input string name, input string detail);
    bit pass;
    pass = (i0_target_state === ref_i0_target_state) &&
           (i1_target_state === ref_i1_target_state);
    tb_report_open(pass, name, detail);
    tb_field_u32("i0_target_state", {30'd0, i0_target_state}, {30'd0, ref_i0_target_state});
    tb_field_u32("i1_target_state", {30'd0, i1_target_state}, {30'd0, ref_i1_target_state});
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic write_state(
    input logic [31:0] pc,
    input logic [1:0]  state
  );
    i0_pc_wb           = pc;
    i0_target_state_wb = state;
    i0_valid_wb        = 1'b1;
    @(posedge clk);
    i0_valid_wb        = 1'b0;
  endtask

  task automatic fsm_step(
    input logic [31:0] pc,
    input logic        taken
  );
    logic [1:0] cur;
    logic [1:0] nxt;

    i0_valid_wb = 1'b0;
    i0_pc       = pc;
    i0_brch_en  = 1'b1;
    #0;
    cur = i0_target_state;
    nxt = state_lut_next(cur, taken);
    write_state(pc, nxt);
  endtask

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    i0_brch_en         = 1'b1;
    i1_brch_en         = 1'b0;
    i0_valid_wb        = 1'b0;
    i1_valid_wb        = 1'b0;
    i0_pc_wb           = '0;
    i1_pc_wb           = '0;
    i0_target_state_wb = 2'b01;
    i1_target_state_wb = 2'b01;
    i0_pc              = PC0;
    i1_pc              = PC1;

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #0;

    tb_banner("state_buffer_tb: DUT vs state_buffer_gm.sv");

    check_states("cold_miss", "no valid entry => default 10");

    i0_pc = BR_PC;
    #0;
    check_states("cold_branch_pc", "branch PC still default before train");

    i0_brch_en = 1'b0;
    #0;
    check_states("brch_en_off", "non-branch lookup forced to default");
    i0_brch_en = 1'b1;

    fsm_step(BR_PC, 1'b0);
    i0_pc = BR_PC;
    #0;
    check_states("train_not_taken", "10 + not taken => 00");

    fsm_step(BR_PC, 1'b1);
    #0;
    check_states("train_taken_from_00", "00 + taken => 01");

    fsm_step(BR_PC, 1'b1);
    #0;
    check_states("train_taken_from_01", "01 + taken => 11");

    fsm_step(BR_PC, 1'b0);
    #0;
    check_states("train_not_taken_from_11", "11 + not taken => 10");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "state_buffer_tb failed");
    $finish;
  end

endmodule
