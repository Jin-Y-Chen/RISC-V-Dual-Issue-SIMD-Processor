`timescale 1ns / 1ps

// state_buffer_tb — combinational storage lookup and WB update; FSM via state_LUT.
module state_buffer_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam logic [31:0] PC0   = 32'h0000_1000;
  localparam logic [31:0] PC1   = 32'h0000_1004;
  localparam logic [31:0] BR_PC = 32'h0000_2000;

  logic [31:0] i0_pc;
  logic [31:0] i1_pc;
  logic        i0_brch_en;
  logic        i1_brch_en;
  logic        i0_valid_wb;
  logic        i1_valid_wb;
  logic [31:0] i0_pc_wb;
  logic [31:0] i1_pc_wb;
  logic [1:0]  i0_target_state_wb;
  logic [1:0]  i1_target_state_wb;
  logic [1:0]  i0_target_state;
  logic [1:0]  i1_target_state;

  logic [1:0]  cur_state;
  logic [1:0]  next_state;
  logic        pc_sctrl_lut;

  int pass_cnt;
  int fail_cnt;

  state_buffer #(
    .INDEX_W(6)
  ) dut (.*);

  state_LUT u_lut (
    .state      (cur_state),
    .pc_sctrl   (pc_sctrl_lut),
    .next_state (next_state)
  );

  task automatic check_slot0(
    input string       name,
    input string       detail,
    input logic [1:0]  exp_state
  );
    bit pass;
    #0;
    pass = (i0_target_state === exp_state);
    tb_report_open(pass, name, detail);
    tb_field_u32("i0_target_state", {30'd0, i0_target_state}, {30'd0, exp_state});
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
    #0;
    i0_valid_wb        = 1'b0;
  endtask

  task automatic fsm_step(
    input logic [31:0] pc,
    input logic        taken
  );
    i0_pc        = pc;
    i0_brch_en   = 1'b1;
    #0;
    cur_state    = i0_target_state;
    pc_sctrl_lut = taken;
    #0;
    write_state(pc, next_state);
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    i0_brch_en  = 1'b1;
    i1_brch_en  = 1'b0;
    i0_valid_wb = 1'b0;
    i1_valid_wb = 1'b0;
    i0_pc       = PC0;
    i1_pc       = PC1;

    tb_banner("state_buffer_tb - combinational storage lookup and WB update");

    #0;

    check_slot0("cold_miss",
                "no valid entry => default 01",
                2'b01);

    i0_pc = BR_PC;
    check_slot0("cold_branch_pc",
                "branch PC still default before train",
                2'b01);

    i0_brch_en = 1'b0;
    check_slot0("brch_en_off",
                "non-branch lookup forced to default",
                2'b01);
    i0_brch_en = 1'b1;

    fsm_step(BR_PC, 1'b0);
    i0_pc = BR_PC;
    check_slot0("train_not_taken",
                "01 + not taken => 00",
                2'b00);

    fsm_step(BR_PC, 1'b1);
    check_slot0("train_taken_from_00",
                "00 + taken => 01",
                2'b01);

    fsm_step(BR_PC, 1'b1);
    check_slot0("train_taken_from_01",
                "01 + taken => 11",
                2'b11);

    fsm_step(BR_PC, 1'b0);
    check_slot0("train_not_taken_from_11",
                "11 + not taken => 10",
                2'b10);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "state_buffer_tb failed");
    $finish;
  end

endmodule
