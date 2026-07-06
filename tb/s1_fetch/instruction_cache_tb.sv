`timescale 1ns / 1ps

// instruction_cache_tb — dual fetch; hex image preload; line-by-line read checks.

import rv_dis_pkg::*;

module instruction_cache_tb;

  `include "../common/tb_console.svh"
  `include "../common/imem_hex_loader.svh"

  localparam int INDEX_W = PC_INDEX_AW;
  localparam int WAYS    = 4;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SETS    = (1 << INDEX_W) / WAYS;

  localparam string HEX_FILE        = "demo_instructions.hex";
  localparam string CACHE_DUMP_FILE = "instruction_cache_final.txt";
  localparam word_t MISS_PC         = word_t'(32'h0000_2000);

  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] instr0;
  logic [31:0] instr1;

  imem_prog_entry_t prog [256];
  int               prog_len;

  logic [32:0] ref_bank [SETS][WAYS];

  int pass_cnt;
  int fail_cnt;

  instruction_cache #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  function automatic logic [$clog2(SETS)-1:0] idx_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic logic [WAY_AW-1:0] idx_way(input word_t pc);
    return pc[WAY_AW+1:2];
  endfunction

  function automatic instr_t ref_lookup(input word_t pc);
    logic [32:0] entry;
    entry = ref_bank[idx_set(pc)][idx_way(pc)];
    return entry[32] ? instr_t'(entry[31:0]) : instr_t'('0);
  endfunction

  task automatic ref_preload(input word_t pc, input instr_t word);
    ref_bank[idx_set(pc)][idx_way(pc)] = {1'b1, word};
  endtask

  task automatic drive(input word_t pc0_v, input word_t pc1_v);
    pc0 = pc0_v;
    pc1 = pc1_v;
    #1;
  endtask

  task automatic check_fetch(
    input string       name,
    input string       detail,
    input instr_t      exp_i0,
    input instr_t      exp_i1
  );
    bit pass;
    pass = (instr0 === exp_i0) && (instr1 === exp_i1);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("pc0", pc0);
    tb_field_in_u32("pc1", pc1);
    $display("");
    tb_log_section("check");
    tb_field_u32("instr0", instr0, exp_i0);
    tb_field_u32("instr1", instr1, exp_i1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic load_program_into_caches;
    for (int i = 0; i < prog_len; i++) begin
      dut.bank[idx_set(prog[i].pc)][idx_way(prog[i].pc)] =
        {1'b1, prog[i].word[31:0]};
      ref_preload(prog[i].pc, instr_t'(prog[i].word));
    end
  endtask

  initial begin
    string case_name;
    string case_detail;
    word_t pc_a;
    word_t pc_b;
    instr_t exp_a;
    instr_t exp_b;

    pass_cnt = 0;
    fail_cnt = 0;

    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        ref_bank[s][w] = '0;
      end
    end

    tb_banner("instruction_cache_tb — hex image load and line-by-line fetch");

    imem_load_hex_program(HEX_FILE, prog, prog_len);
    if (prog_len == 0)
      $fatal(1, "instruction_cache_tb: no instructions loaded from %s", HEX_FILE);
    $display("[INFO] Loaded %0d instruction words from %s (base 0x%08h)",
             prog_len, HEX_FILE, prog[0].pc);

    // -------------------------------------------------------------------------
    // Cold miss before preload
    // -------------------------------------------------------------------------
    drive(prog[0].pc, prog[0].pc + word_t'(32'd4));
    check_fetch("cold_miss_pair",
                "empty I$ => miss returns 32'h0 on both ports",
                instr_t'('0), instr_t'('0));

    // -------------------------------------------------------------------------
    // Load demo_instructions.hex into set/way slots
    // -------------------------------------------------------------------------
    load_program_into_caches();

    // -------------------------------------------------------------------------
    // Line-by-line: each program word on I0 (single-slot read)
    // -------------------------------------------------------------------------
    for (int i = 0; i < prog_len; i++) begin
      pc_a  = prog[i].pc;
      exp_a = instr_t'(prog[i].word);
      case_name   = $sformatf("line_i0_%08h", pc_a);
      case_detail = $sformatf("hex image insn 0x%08h at byte PC 0x%08h on port I0",
                               prog[i].word, pc_a);
      drive(pc_a, pc_a);
      check_fetch(case_name, case_detail, exp_a, exp_a);
    end

    // -------------------------------------------------------------------------
    // Line-by-line: dual-fetch pairs (even/odd lane PCs from demo program)
    // -------------------------------------------------------------------------
    for (int i = 0; i < prog_len - 1; i++) begin
      pc_a  = prog[i].pc;
      pc_b  = prog[i+1].pc;
      exp_a = instr_t'(prog[i].word);
      exp_b = instr_t'(prog[i+1].word);
      case_name   = $sformatf("pair_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("dual fetch sequential pair [%0d/%0d]",
                               i, prog_len - 2);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail, exp_a, exp_b);
    end

    // -------------------------------------------------------------------------
    // Structural checks
    // -------------------------------------------------------------------------
    drive(prog[0].pc, prog[1].pc);
    check_fetch("repeat_first_pair",
                "re-read first dual-issue pair after line sweep",
                instr_t'(prog[0].word), instr_t'(prog[1].word));

    drive(prog[prog_len-2].pc, prog[prog_len-1].pc);
    check_fetch("last_pair",
                "final sequential pair at end of demo program",
                instr_t'(prog[prog_len-2].word), instr_t'(prog[prog_len-1].word));

    drive(MISS_PC, MISS_PC + word_t'(32'd4));
    check_fetch("unloaded_miss",
                "address outside hex image => miss 32'h0",
                instr_t'('0), instr_t'('0));

    dut.dump_final(CACHE_DUMP_FILE);
    $display("");
    $display("[INFO] Cache dump written to %s", CACHE_DUMP_FILE);

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "instruction_cache_tb failed");
`ifdef TRACE_VCD
    $dumpoff;
`endif
    $finish;
  end

endmodule
