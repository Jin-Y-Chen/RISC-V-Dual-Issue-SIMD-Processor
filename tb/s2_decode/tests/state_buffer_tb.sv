`timescale 1ns / 1ps

import rv_dis_pkg::*;

`include "../../common/utils/tb_console.svh"

// state_buffer_tb - DUT vs gm/state_buffer_gm.sv (bank replica + WB bypass).
// Optional +state_dump=<path> writes occupied-set bank dump (2-bit states).
module state_buffer_tb;

  localparam int INDEX_W = 6;
  localparam int DATA_W  = 2;
  localparam int WAYS    = 16;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SET_AW  = INDEX_W - WAY_AW;
  localparam int SETS    = (1 << INDEX_W) / WAYS;

  localparam logic [31:0] PC0   = 32'h0000_1000;
  localparam logic [31:0] PC1   = 32'h0000_1004;
  localparam logic [31:0] BR_PC = 32'h0000_2000;

  word_t     pc            [2];
  logic      brch_en       [2];
  logic      valid_wb      [2];
  word_t     brch_pc_wb    [2];
  br_state_t brch_state_wb [2];
  br_state_t brch_state    [2];
  logic      state_valid   [2];
  br_state_t ref_brch_state  [2];
  logic      ref_state_valid [2];
  logic      clk, rst_n;

  int pass_cnt;
  int fail_cnt;

  state_buffer #(
    .INDEX_W(INDEX_W),
    .DATA_W (DATA_W),
    .WAYS   (WAYS)
  ) dut (
    .clk, .rst_n, .pc, .brch_en, .valid_wb, .brch_pc_wb, .brch_state_wb,
    .brch_state, .state_valid
  );

  state_buffer_gm #(
    .INDEX_W(INDEX_W),
    .DATA_W (DATA_W),
    .WAYS   (WAYS)
  ) u_state_buffer_gm (
    .clk, .rst_n, .pc, .brch_en, .valid_wb, .brch_pc_wb, .brch_state_wb,
    .brch_state(ref_brch_state), .state_valid(ref_state_valid)
  );

  function automatic logic [31:0] pc_of(input int set_i, input int way_i);
    pc_of = (set_i << (WAY_AW + 2)) | (way_i << 2);
  endfunction

  function automatic logic [1:0] state_of(input int set_i, input int way_i);
    state_of = (set_i + way_i) & 2'h3;
  endfunction

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

  task automatic dump_state_txt(input string path);
    int fd;
    bit set_hit;
    logic       v;
    logic [1:0] st;

    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("dump_state_txt: cannot open %s", path);
      return;
    end

    $fdisplay(fd, "# state_buffer DUT bank");
    $fdisplay(fd, "# INDEX_W=%0d DATA_W=%0d WAYS=%0d SETS=%0d",
              INDEX_W, DATA_W, WAYS, SETS);
    $fdisplay(fd, "# occupied sets only; each way shown (V=0 => -)");
    $fdisplay(fd, "# columns: way[3:0]  V  state[1:0]");
    $fdisplay(fd, "# state: 00 SN, 01 WN, 10 WT, 11 ST");

    for (int s = 0; s < SETS; s++) begin
      set_hit = 1'b0;
      for (int w = 0; w < WAYS; w++)
        if (dut.bank[s][w][DATA_W])
          set_hit = 1'b1;
      if (!set_hit)
        continue;

      $fdisplay(fd, "");
      $fdisplay(fd, "# set %0d", s);
      for (int w = 0; w < WAYS; w++) begin
        v  = dut.bank[s][w][DATA_W];
        st = dut.bank[s][w][1:0];
        if (v)
          $fdisplay(fd, "  %04b  %0d  %02b", w[3:0], v, st);
        else
          $fdisplay(fd, "  %04b  %0d  -", w[3:0], v);
      end
    end

    $fclose(fd);
    $display("[INFO] state dump -> %s", path);
  endtask

  task automatic check_states(input string name, input string detail);
    bit pass;
    pass = (brch_state[0] === ref_brch_state[0]) &&
           (brch_state[1] === ref_brch_state[1]) &&
           (state_valid[0] === ref_state_valid[0]) &&
           (state_valid[1] === ref_state_valid[1]);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_bit("clk",              clk);
    tb_field_in_bit("rst_n",            rst_n);
    tb_field_in_u32("pc[0]",            pc[0]);
    tb_field_in_u32("pc[1]",            pc[1]);
    tb_field_in_bit("brch_en[0]",       brch_en[0]);
    tb_field_in_bit("brch_en[1]",       brch_en[1]);
    tb_field_in_bit("valid_wb[0]",      valid_wb[0]);
    tb_field_in_bit("valid_wb[1]",      valid_wb[1]);
    tb_field_in_u32("brch_pc_wb[0]",    brch_pc_wb[0]);
    tb_field_in_u32("brch_pc_wb[1]",    brch_pc_wb[1]);
    tb_field_in_u2 ("brch_state_wb[0]", brch_state_wb[0]);
    tb_field_in_u2 ("brch_state_wb[1]", brch_state_wb[1]);
    $display("");
    tb_log_section("check");
    tb_field_u2("brch_state[0]", brch_state[0], ref_brch_state[0]);
    tb_field_u2("brch_state[1]", brch_state[1], ref_brch_state[1]);
    tb_field_bit("state_valid[0]", state_valid[0], ref_state_valid[0]);
    tb_field_bit("state_valid[1]", state_valid[1], ref_state_valid[1]);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic write_dual(
    input logic [31:0] pc0,
    input logic [1:0]  st0,
    input logic [31:0] pc1,
    input logic [1:0]  st1
  );
    brch_pc_wb[0]    = pc0;
    brch_state_wb[0] = st0;
    brch_pc_wb[1]    = pc1;
    brch_state_wb[1] = st1;
    valid_wb[0]      = 1'b1;
    valid_wb[1]      = 1'b1;
    @(negedge clk);
    @(posedge clk);
    valid_wb[0] = 1'b0;
    valid_wb[1] = 1'b0;
  endtask

  task automatic write_state(
    input logic [31:0] pc_v,
    input logic [1:0]  state
  );
    brch_pc_wb[0]    = pc_v;
    brch_state_wb[0] = state;
    valid_wb[0]      = 1'b1;
    valid_wb[1]      = 1'b0;
    @(negedge clk);
    @(posedge clk);
    valid_wb[0] = 1'b0;
  endtask

  task automatic fsm_step(
    input logic [31:0] pc_v,
    input logic        taken
  );
    logic [1:0] cur;
    logic [1:0] nxt;

    valid_wb[0] = 1'b0;
    valid_wb[1] = 1'b0;
    pc[0]       = pc_v;
    brch_en[0]  = 1'b1;
    #0;
    cur = brch_state[0];
    nxt = state_lut_next(cur, taken);
    write_state(pc_v, nxt);
  endtask

  task automatic fill_and_check_bank;
    int s0, w0, w1;
    logic [31:0] pc0_v, pc1_v;
    logic [1:0]  st0_v, st1_v;

    for (s0 = 0; s0 < SETS; s0++) begin
      for (w0 = 0; w0 < WAYS; w0 += 2) begin
        w1    = w0 + 1;
        pc0_v = pc_of(s0, w0);
        st0_v = state_of(s0, w0);
        pc1_v = pc_of(s0, w1);
        st1_v = state_of(s0, w1);
        write_dual(pc0_v, st0_v, pc1_v, st1_v);
      end
    end

    for (s0 = 0; s0 < SETS; s0++) begin
      w0 = (s0 * 5) % WAYS;
      pc[0]      = pc_of(s0, w0);
      pc[1]      = pc_of(s0, (w0 + 1) % WAYS);
      brch_en[0] = 1'b1;
      brch_en[1] = 1'b1;
      #0;
      check_states(
        $sformatf("fill_s%0d_w%0d", s0, w0),
        $sformatf("bank hit set=%0d way=%0d state=%02b",
                  s0, w0, state_of(s0, w0))
      );
    end
  endtask

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    brch_en[0]       = 1'b1;
    brch_en[1]       = 1'b0;
    valid_wb[0]      = 1'b0;
    valid_wb[1]      = 1'b0;
    brch_pc_wb[0]    = '0;
    brch_pc_wb[1]    = '0;
    brch_state_wb[0] = 2'b01;
    brch_state_wb[1] = 2'b01;
    pc[0]            = PC0;
    pc[1]            = PC1;

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #0;

    tb_banner("state_buffer_tb: DUT vs state_buffer_gm.sv");

    check_states("cold_miss", "no valid entry => default 10, state_valid=0");

    pc[0] = BR_PC;
    #0;
    check_states("cold_branch_pc", "branch PC still default before train");

    brch_en[0] = 1'b0;
    #0;
    check_states("brch_en_off", "non-branch lookup forced to default");
    brch_en[0] = 1'b1;

    fsm_step(BR_PC, 1'b0);
    pc[0] = BR_PC;
    #0;
    check_states("train_not_taken", "10 + not taken => 00, state_valid=1");

    fsm_step(BR_PC, 1'b1);
    #0;
    check_states("train_taken_from_00", "00 + taken => 01");

    fsm_step(BR_PC, 1'b1);
    #0;
    check_states("train_taken_from_01", "01 + taken => 11");

    fsm_step(BR_PC, 1'b0);
    #0;
    check_states("train_not_taken_from_11", "11 + not taken => 10");

    fill_and_check_bank();

    if ($test$plusargs("state_dump")) begin
      string dump_path;
      dump_path = "state_bank.txt";
      if (!$value$plusargs("state_dump=%s", dump_path))
        dump_path = "state_bank.txt";
      dump_state_txt(dump_path);
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "state_buffer_tb failed");
    $finish;
  end

endmodule
