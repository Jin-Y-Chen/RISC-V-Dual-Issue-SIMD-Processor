`timescale 1ns / 1ps

// instruction_cache_tb — dual fetch; DUT bank preload vs gm LUT; image from .mem.
// Vectors: independent I0/I1, delta +4, delta +8; each vector applies pc0/pc1 on posedge clk.
// Vivado: add demo_instructions.mem next to this TB (tb/s1_fetch/) or pass +imem_mem=<path>.
import rv_dis_pkg::*;

`include "../include/tb_console.svh"
`include "../include/imem_hex_loader.svh"

module instruction_cache_tb;

  localparam int INDEX_W = PC_INDEX_AW;
  localparam int WAYS    = 4;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SETS    = (1 << INDEX_W) / WAYS;

  localparam string MEM_FILE_DEFAULT = "demo_instructions.mem";
  localparam int    CLK_PERIOD       = 10;
  localparam word_t MISS_PC          = 32'h0000_2000;

  logic        clk;
  logic        rst_n;
  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] instr0;
  logic [31:0] instr1;
  instr_t      ref_instr0;
  instr_t      ref_instr1;

  imem_prog_entry_t prog [256];
  int               prog_len;

  int pass_cnt;
  int fail_cnt;

  instruction_cache #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (instr0),
    .instr1 (instr1)
  );

  instruction_cache_gm u_icache_gm (
    .pc0    (pc0),
    .pc1    (pc1),
    .instr0 (ref_instr0),
    .instr1 (ref_instr1)
  );

  function automatic logic [$clog2(SETS)-1:0] idx_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic logic [WAY_AW-1:0] idx_way(input word_t pc);
    return pc[WAY_AW+1:2];
  endfunction

  task automatic preload_slot(input word_t pc, input instr_t word);
    dut.bank[idx_set(pc)][idx_way(pc)] = {1'b1, word[31:0]};
  endtask

  task automatic drive(input word_t pc0_v, input word_t pc1_v);
    @(posedge clk);
    pc0 = pc0_v;
    pc1 = pc1_v;
    #0;
  endtask

  task automatic check_cold_miss(
    input string name,
    input string detail
  );
    bit pass;
    pass = (instr0 === 32'h0) && (instr1 === 32'h0);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("pc0", pc0);
    tb_field_in_u32("pc1", pc1);
    $display("");
    tb_log_section("check");
    tb_field_u32("instr0", instr0, 32'h0);
    tb_field_u32("instr1", instr1, 32'h0);
    $display("[note] gm image ref instr0=0x%08h instr1=0x%08h (not compared on miss)",
             ref_instr0, ref_instr1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_fetch(
    input string  name,
    input string  detail
  );
    bit pass;
    pass = (instr0 === ref_instr0) && (instr1 === ref_instr1);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("pc0", pc0);
    tb_field_in_u32("pc1", pc1);
    $display("");
    tb_log_section("check");
    tb_field_u32("instr0", instr0, ref_instr0);
    tb_field_u32("instr1", instr1, ref_instr1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    clk = 1'b0;
  end

  always #(CLK_PERIOD/2) clk <= ~clk;

  initial begin
    string case_name;
    string case_detail;
    word_t pc_a;
    word_t pc_b;

    string mem_file;

    pass_cnt = 0;
    fail_cnt = 0;

    mem_file = MEM_FILE_DEFAULT;
    void'($value$plusargs("imem_mem=%s", mem_file));

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    tb_banner("instruction_cache_tb: DUT vs instruction_cache_gm.sv");

    imem_load_mem_program(mem_file, prog, prog_len);
    if (prog_len == 0) begin
      $error("instruction_cache_tb: no instructions loaded from %s", mem_file);
      $finish;
    end
    $display("[INFO] Loaded %0d instruction words from %s (base 0x%08h)",
             prog_len, mem_file, prog[0].pc);

    drive(prog[0].pc, prog[0].pc + word_t'(32'd4));
    check_cold_miss("cold_miss_pair",
                    "empty I$ => DUT miss 32'h0; gm holds hex image separately");

    for (int i = 0; i < prog_len; i++)
      preload_slot(prog[i].pc, instr_t'(prog[i].word));

    // Port I0 only — I1 at inactive miss address (pc0 != pc1).
    for (int i = 0; i < prog_len; i++) begin
      pc_a = prog[i].pc;
      case_name   = $sformatf("i0_only_%08h", pc_a);
      case_detail = $sformatf("I0 hit @0x%08h; I1 inactive @0x%08h", pc_a, MISS_PC);
      drive(pc_a, MISS_PC);
      check_fetch(case_name, case_detail);
    end

    // Port I1 only — I0 at inactive miss address.
    for (int i = 0; i < prog_len; i++) begin
      pc_a = prog[i].pc;
      case_name   = $sformatf("i1_only_%08h", pc_a);
      case_detail = $sformatf("I0 inactive @0x%08h; I1 hit @0x%08h", MISS_PC, pc_a);
      drive(MISS_PC, pc_a);
      check_fetch(case_name, case_detail);
    end

    // Dual fetch, delta +4 (sequential in-pair: pc, pc+4).
    for (int i = 0; i < prog_len - 1; i++) begin
      pc_a = prog[i].pc;
      pc_b = pc_a + word_t'(32'd4);
      case_name   = $sformatf("delta4_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("dual fetch +4 spacing [%0d/%0d]", i, prog_len - 2);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail);
    end

    // Dual fetch, delta +8 (skip one slot: pc, pc+8).
    for (int i = 0; i < prog_len - 2; i++) begin
      pc_a = prog[i].pc;
      pc_b = pc_a + word_t'(32'd8);
      case_name   = $sformatf("delta8_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("dual fetch +8 spacing [%0d/%0d]", i, prog_len - 3);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail);
    end

    drive(prog[0].pc, prog[0].pc + word_t'(32'd4));
    check_fetch("repeat_first_delta4",
                "re-read first +4 pair after sweeps");

    drive(prog[prog_len-2].pc, prog[prog_len-1].pc);
    check_fetch("last_delta4",
                "final +4 pair at end of demo program");

    drive(MISS_PC, MISS_PC + word_t'(32'd4));
    check_fetch("unloaded_miss_delta4",
                "both ports miss outside demo .mem image => 32'h0");

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $error("instruction_cache_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
