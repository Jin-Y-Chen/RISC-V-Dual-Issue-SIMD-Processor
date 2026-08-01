`timescale 1ns / 1ps

import rv_dis_pkg::word_t;

`include "../../common/utils/tb_console.svh"

// target_buffer_tb - BTB lookup/WB; DUT vs gm/target_buffer_gm.sv.
// Each vector applies inputs on posedge clk.
module target_buffer_tb;

  localparam int INDEX_W = 13;
  localparam int WAYS    = 16;
  localparam int SETS    = (1 << INDEX_W) / WAYS;
  localparam int CLK_PERIOD = 10;

  localparam word_t PC0       = word_t'(32'h0000_1000);
  localparam word_t PC1       = word_t'(32'h0000_1004);
  localparam word_t BR_PC     = word_t'(32'h0000_2000);
  localparam word_t BR_TARGET = word_t'(32'h0000_3000);
  localparam word_t BR2_PC    = word_t'(32'h0000_2010);
  localparam word_t BR2_TGT   = word_t'(32'h0000_4000);
  localparam word_t COLD_PC   = word_t'(32'h0000_8000);

  logic [31:0] i0_pc;
  logic [31:0] i1_pc;
  logic        i0_valid_wb;
  logic        i1_valid_wb;
  logic [31:0] i0_pc_wb;
  logic [31:0] i1_pc_wb;
  logic [31:0] i0_pc_target_wb;
  logic [31:0] i1_pc_target_wb;
  logic        i0_valid;
  logic        i1_valid;
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;
  logic        ref_i0_valid;
  logic        ref_i1_valid;
  logic [31:0] ref_i0_pc_target;
  logic [31:0] ref_i1_pc_target;
  logic        clk;
  logic        rst_n;

  int pass_cnt;
  int fail_cnt;

  target_buffer #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (.*);

  target_buffer_gm #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) u_target_gm (
    .clk             (clk),
    .rst_n           (rst_n),
    .i0_pc           (i0_pc),
    .i1_pc           (i1_pc),
    .i0_valid_wb     (i0_valid_wb),
    .i1_valid_wb     (i1_valid_wb),
    .i0_pc_wb        (i0_pc_wb),
    .i1_pc_wb        (i1_pc_wb),
    .i0_pc_target_wb (i0_pc_target_wb),
    .i1_pc_target_wb (i1_pc_target_wb),
    .i0_valid        (ref_i0_valid),
    .i1_valid        (ref_i1_valid),
    .i0_pc_target    (ref_i0_pc_target),
    .i1_pc_target    (ref_i1_pc_target)
  );

  task automatic dump_btb_txt(input string path);
    int fd;
    bit set_hit;
    logic        v;
    logic [31:0] tgt;

    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("dump_btb_txt: cannot open %s", path);
      return;
    end

    // WAYS=16 => way index is PC[5:2] (4 bits); print every way in occupied sets.
    $fdisplay(fd, "# target_buffer DUT bank");
    $fdisplay(fd, "# INDEX_W=%0d WAYS=%0d SETS=%0d", INDEX_W, WAYS, SETS);
    $fdisplay(fd, "# occupied sets only; each way shown (V=0 => -)");
    $fdisplay(fd, "# columns: way[3:0]  V  target");

    for (int s = 0; s < SETS; s++) begin
      set_hit = 1'b0;
      for (int w = 0; w < WAYS; w++)
        if (dut.bank[s][w][32])
          set_hit = 1'b1;
      if (!set_hit)
        continue;

      $fdisplay(fd, "");
      $fdisplay(fd, "# set %0d", s);
      for (int w = 0; w < WAYS; w++) begin
        v   = dut.bank[s][w][32];
        tgt = dut.bank[s][w][31:0];
        if (v)
          $fdisplay(fd, "  %04b  %0d  0x%08h", w[3:0], v, tgt);
        else
          $fdisplay(fd, "  %04b  %0d  -", w[3:0], v);
      end
    end

    $fclose(fd);
    $display("[INFO] BTB dump -> %s", path);
  endtask

  task automatic drive(
    input word_t i0_pc_v,
    input word_t i1_pc_v,
    input logic  v0_wb,
    input word_t pc0_wb,
    input word_t tgt0_wb,
    input logic  v1_wb,
    input word_t pc1_wb,
    input word_t tgt1_wb
  );
    @(posedge clk);
    i0_pc           = i0_pc_v;
    i1_pc           = i1_pc_v;
    i0_valid_wb     = v0_wb;
    i1_valid_wb     = v1_wb;
    i0_pc_wb        = pc0_wb;
    i1_pc_wb        = pc1_wb;
    i0_pc_target_wb = tgt0_wb;
    i1_pc_target_wb = tgt1_wb;
    #0;
  endtask

  task automatic check_state(input string name, input string detail);
    bit pass;

    pass = (i0_valid === ref_i0_valid) && (i1_valid === ref_i1_valid)
        && (i0_pc_target === ref_i0_pc_target) && (i1_pc_target === ref_i1_pc_target);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_clk(clk);
    tb_field_in_bit("rst_n",           rst_n);
    tb_field_in_u32("i0_pc",           i0_pc);
    tb_field_in_u32("i1_pc",           i1_pc);
    tb_field_in_bit("i0_valid_wb",     i0_valid_wb);
    tb_field_in_bit("i1_valid_wb",     i1_valid_wb);
    tb_field_in_u32("i0_pc_wb",        i0_pc_wb);
    tb_field_in_u32("i1_pc_wb",        i1_pc_wb);
    tb_field_in_u32("i0_pc_target_wb", i0_pc_target_wb);
    tb_field_in_u32("i1_pc_target_wb", i1_pc_target_wb);
    $display("");
    tb_log_section("check");
    tb_field_bit("i0_valid",     i0_valid,     ref_i0_valid);
    tb_field_bit("i1_valid",     i1_valid,     ref_i1_valid);
    tb_field_u32("i0_pc_target", i0_pc_target, ref_i0_pc_target);
    tb_field_u32("i1_pc_target", i1_pc_target, ref_i1_pc_target);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    clk = 1'b0;
  end

  always #(CLK_PERIOD/2) clk <= ~clk;

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    i0_valid_wb     = 1'b0;
    i1_valid_wb     = 1'b0;
    i0_pc_wb        = '0;
    i1_pc_wb        = '0;
    i0_pc_target_wb = '0;
    i1_pc_target_wb = '0;

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    tb_banner("target_buffer_tb: DUT vs target_buffer_gm.sv");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("cold_miss", "empty bank => i0/i1 valid=0, target=0");

    drive(PC0, PC1, 1'b1, BR_PC, BR_TARGET, 1'b0, '0, '0);
    check_state("i0_wb_train", "WB cycle still reads prior miss (lookup pc unchanged)");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i0_wb_hit", "trained branch PC returns stored target on I0");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b1, BR2_PC, BR2_TGT);
    check_state("i1_wb_train", "I1 WB installs second entry");

    drive(PC0, BR2_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i1_wb_hit", "I1 trained PC returns stored target");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(PC0, PC1,
          1'b1, PC0, word_t'(32'h0000_A000),
          1'b1, PC1, word_t'(32'h0000_B004));
    check_state("dual_wb_same_cycle",
                "both WB valid same cycle - each way updated independently");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_wb_hit", "both slots hit their trained targets");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(BR_PC, PC1,
          1'b1, BR_PC, word_t'(32'h0000_D003),
          1'b0, '0,    '0);
    check_state("overwrite_align",
                "re-train same index overwrites; target imm_align4 on store");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("overwrite_hit", "read returns updated aligned target 0xD000");

    drive(COLD_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("index_miss", "untrained PC => target=0; other slot unchanged");

    drive(COLD_PC, PC1,
          1'b1, COLD_PC, word_t'(32'h0000_E000),
          1'b0, '0,      '0);
    check_state("read_during_wb",
                "lookup pc == wb pc same cycle => hit new target immediately");

    drive(BR_PC, BR_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_port_same_pc", "i0_pc == i1_pc => identical targets");

    if ($test$plusargs("btb_dump")) begin
      string dump_path;
      dump_path = "btb_bank.txt";
      void'($value$plusargs("btb_dump=%s", dump_path));
      dump_btb_txt(dump_path);
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $error("target_buffer_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
