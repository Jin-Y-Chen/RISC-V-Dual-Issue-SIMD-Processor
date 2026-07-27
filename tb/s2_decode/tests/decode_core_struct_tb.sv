`timescale 1ns / 1ps

// Decode struct smoke + nested-speculation stall vs per-lane spec_en_id.
// All DUT slot ports are [2] arrays: index 0 = I0, index 1 = I1.
import rv_dis_pkg::*;

`include "../../common/utils/tb_console.svh"

module decode_core_struct_tb;
  logic        clk;
  logic        rst_n;
  logic        fetch_valid_id  [2];
  logic        spec_en_id      [2];
  instr_t      instr_id        [2];
  word_t       pc_id           [2];
  word_t       pc_target_id    [2];
  logic        target_valid_id [2];
  logic        brch_valid_wb   [2];
  word_t       brch_pc_wb      [2];
  br_state_t   brch_state_wb   [2];

  logic        lane_sel        [2];
  opcode_t     opcode          [2];
  funct3_t     funct3          [2];
  funct7_t     funct7          [2];
  gpr_addr_t   rd_addr         [2];
  gpr_addr_t   rs1_addr        [2];
  gpr_addr_t   rs2_addr        [2];
  word_t       imm             [2];
  logic        valid           [2];
  logic        brch_en         [2];
  logic        store_en        [2];
  logic        rs1_use         [2];
  logic        rs2_use         [2];
  logic        reg_write       [2];
  br_state_t   brch_state      [2];
  logic        state_valid     [2];
  word_t       pc_predict      [2];
  logic        pred_taken      [2];
  logic        pred_valid_wb   [2];
  logic        nest_spec_stall [2];

  int pass_cnt, fail_cnt;

  s2_decode_struct dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  // JAL x0, 0 — always control-flow for nest stall checks
  localparam instr_t JAL0 = 32'h0000006f;

  task automatic expect_stall(
    input string name,
    input logic  exp_i0,
    input logic  exp_i1
  );
    bit pass;
    #1;
    pass = (nest_spec_stall[0] === exp_i0) && (nest_spec_stall[1] === exp_i1);
    tb_report_open(pass, name, $sformatf("spec=%0b%0b", spec_en_id[1], spec_en_id[0]));
    tb_log_section("inputs");
    tb_field_in_bit("clk",               clk);
    tb_field_in_bit("rst_n",             rst_n);
    for (int i = 0; i < N_DUAL; i++) begin
      tb_field_in_bit($sformatf("fetch_valid_id[%0d]", i), fetch_valid_id[i]);
      tb_field_in_bit($sformatf("spec_en_id[%0d]", i),    spec_en_id[i]);
      tb_field_in_u32($sformatf("instr_id[%0d]", i),      instr_id[i]);
      tb_field_in_u32($sformatf("pc_id[%0d]", i),         pc_id[i]);
      tb_field_in_u32($sformatf("pc_target_id[%0d]", i),  pc_target_id[i]);
      tb_field_in_bit($sformatf("brch_valid_wb[%0d]", i), brch_valid_wb[i]);
      tb_field_in_u32($sformatf("brch_pc_wb[%0d]", i),    brch_pc_wb[i]);
      tb_field_in_u2 ($sformatf("brch_state_wb[%0d]", i), brch_state_wb[i]);
    end
    $display("");
    tb_log_section("check");
    tb_field_bit("nest_spec_stall[0]", nest_spec_stall[0], exp_i0);
    tb_field_bit("nest_spec_stall[1]", nest_spec_stall[1], exp_i1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0; fail_cnt = 0;
    rst_n = 0;
    fetch_valid_id  = '{1'b0, 1'b0};
    spec_en_id      = '{1'b0, 1'b0};
    instr_id        = '{'0, '0};
    pc_id           = '{'0, '0};
    pc_target_id    = '{'0, '0};
    target_valid_id = '{1'b0, 1'b0};
    brch_valid_wb   = '{1'b0, 1'b0};
    brch_pc_wb      = '{'0, '0};
    brch_state_wb   = '{'0, '0};

    tb_banner("decode_core_struct_tb: nest_spec_stall");
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    spec_en_id = '{1'b0, 1'b0};
    fetch_valid_id = '{1'b1, 1'b1};
    instr_id   = '{JAL0, JAL0};
    pc_id      = '{32'h100, 32'h104};
    @(posedge clk);
    expect_stall("none_no_nest", 1'b0, 1'b0);

    spec_en_id = '{1'b1, 1'b0};
    @(posedge clk);
    expect_stall("spec0_nests_i0", 1'b1, 1'b0);

    spec_en_id = '{1'b0, 1'b1};
    @(posedge clk);
    expect_stall("spec1_nests_i1", 1'b0, 1'b1);

    spec_en_id = '{1'b1, 1'b1};
    @(posedge clk);
    expect_stall("both_nests", 1'b1, 1'b1);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0) $error("decode_core_struct_tb: %0d failure(s)", fail_cnt);
    $finish;
  end
endmodule
