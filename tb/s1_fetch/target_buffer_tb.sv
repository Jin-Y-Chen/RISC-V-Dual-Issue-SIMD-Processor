`timescale 1ns / 1ps

// target_buffer_tb — BTB lookup (miss => pc+4), WB update, and final bank dump.
module target_buffer_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int INDEX_W = 13;
  localparam int WAYS    = 16;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SETS    = (1 << INDEX_W) / WAYS;

  localparam string BUFFER_DUMP_FILE = "target_buffer_final.txt";

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
  logic [31:0] i0_pc_target;
  logic [31:0] i1_pc_target;

  logic [32:0] ref_bank [SETS][WAYS];

  int pass_cnt;
  int fail_cnt;

  target_buffer #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (.*);

  function automatic logic [WAY_AW-1:0] idx_way(input word_t pc);
    return pc[WAY_AW+1:2];
  endfunction

  function automatic logic [$clog2(SETS)-1:0] idx_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic word_t fallthrough(input word_t pc);
    return pc + word_t'(32'd4);
  endfunction

  function automatic word_t ref_lookup(input word_t pc);
    logic [32:0] entry;
    entry = ref_bank[idx_set(pc)][idx_way(pc)];
    return entry[32] ? word_t'(entry[31:0]) : fallthrough(pc);
  endfunction

  task automatic ref_wb(
    input logic        v0,
    input word_t       pc0_wb,
    input word_t       tgt0,
    input logic        v1,
    input word_t       pc1_wb,
    input word_t       tgt1
  );
    if (v0)
      ref_bank[idx_set(pc0_wb)][idx_way(pc0_wb)] = {1'b1, imm_align4(tgt0)};
    if (v1)
      ref_bank[idx_set(pc1_wb)][idx_way(pc1_wb)] = {1'b1, imm_align4(tgt1)};
  endtask

  task automatic drive(
    input word_t       i0_pc_v,
    input word_t       i1_pc_v,
    input logic        v0_wb,
    input word_t       pc0_wb,
    input word_t       tgt0_wb,
    input logic        v1_wb,
    input word_t       pc1_wb,
    input word_t       tgt1_wb
  );
    ref_wb(v0_wb, pc0_wb, tgt0_wb, v1_wb, pc1_wb, tgt1_wb);

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
    word_t exp_t0, exp_t1;

    exp_t0 = ref_lookup(i0_pc);
    exp_t1 = ref_lookup(i1_pc);

    pass = (i0_pc_target === exp_t0) && (i1_pc_target === exp_t1);

    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
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
    tb_field_u32("i0_pc_target", i0_pc_target, exp_t0);
    tb_field_u32("i1_pc_target", i1_pc_target, exp_t1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        ref_bank[s][w] = '0;
      end
    end

    i0_valid_wb     = 1'b0;
    i1_valid_wb     = 1'b0;
    i0_pc_wb        = '0;
    i1_pc_wb        = '0;
    i0_pc_target_wb = '0;
    i1_pc_target_wb = '0;

    tb_banner("target_buffer_tb — BTB lookup, WB update, final dump");

    // -------------------------------------------------------------------------
    // Cold miss — fallthrough pc+4
    // -------------------------------------------------------------------------
    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("cold_miss",
                "empty bank => i0/i1 predict sequential pc+4");

    // -------------------------------------------------------------------------
    // WB path — I0 train then hit
    // -------------------------------------------------------------------------
    drive(PC0, PC1, 1'b1, BR_PC, BR_TARGET, 1'b0, '0, '0);
    check_state("i0_wb_train",
                "WB cycle still reads prior miss (lookup pc unchanged)");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i0_wb_hit",
                "trained branch PC returns stored target on I0");

    // -------------------------------------------------------------------------
    // WB path — I1 train then hit
    // -------------------------------------------------------------------------
    drive(PC0, PC1, 1'b0, '0, '0, 1'b1, BR2_PC, BR2_TGT);
    check_state("i1_wb_train", "I1 WB installs second entry");

    drive(PC0, BR2_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("i1_wb_hit", "I1 trained PC returns stored target");

    // -------------------------------------------------------------------------
    // Dual WB same cycle — different set/way (PC0 + PC1 share set, diff way)
    // -------------------------------------------------------------------------
    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(PC0, PC1,
          1'b1, PC0, word_t'(32'h0000_A000),
          1'b1, PC1, word_t'(32'h0000_B004));
    check_state("dual_wb_same_cycle",
                "both WB valid same cycle — each way updated independently");

    drive(PC0, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_wb_hit",
                "both slots hit their trained targets");

    // -------------------------------------------------------------------------
    // Overwrite + aligned target on WB
    // -------------------------------------------------------------------------
    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    drive(BR_PC, PC1,
          1'b1, BR_PC, word_t'(32'h0000_D003),
          1'b0, '0,    '0);
    check_state("overwrite_align",
                "re-train same index overwrites; target imm_align4 on store");

    drive(BR_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("overwrite_hit",
                "read returns updated aligned target 0xD000");

    // -------------------------------------------------------------------------
    // Untrained index — fallthrough
    // -------------------------------------------------------------------------
    drive(COLD_PC, PC1, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("index_miss",
                "untrained PC => fallthrough; other slot unchanged");

    // -------------------------------------------------------------------------
    // Read during WB on same PC (combinational write visible same cycle)
    // -------------------------------------------------------------------------
    drive(COLD_PC, PC1,
          1'b1, COLD_PC, word_t'(32'h0000_E000),
          1'b0, '0,      '0);
    check_state("read_during_wb",
                "lookup pc == wb pc same cycle => hit new target immediately");

    // -------------------------------------------------------------------------
    // Both lookup ports same PC
    // -------------------------------------------------------------------------
    drive(BR_PC, BR_PC, 1'b0, '0, '0, 1'b0, '0, '0);
    check_state("dual_port_same_pc",
                "i0_pc == i1_pc => identical targets");

    dut.dump_final(BUFFER_DUMP_FILE);
    $display("");
    $display("[INFO] Buffer dump written to %s", BUFFER_DUMP_FILE);

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "target_buffer_tb failed");
`ifdef TRACE_VCD
    $dumpoff;
`endif
    $finish;
  end

endmodule
