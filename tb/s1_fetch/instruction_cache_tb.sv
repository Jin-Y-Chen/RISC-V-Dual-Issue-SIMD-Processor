`timescale 1ns / 1ps

// instruction_cache_tb — dual fetch; hex preload; DUT vs gm/instruction_cache_gm.sv.
import rv_dis_pkg::*;

module instruction_cache_tb;

  `include "../common/tb_console.svh"
  `include "../common/imem_hex_loader.svh"

  localparam int INDEX_W = PC_INDEX_AW;
  localparam int WAYS    = 4;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SETS    = (1 << INDEX_W) / WAYS;

  localparam string HEX_FILE = "demo_instructions.hex";

  logic        clk;
  logic        rst_n;
  logic        preload_en;
  word_t       preload_pc;
  instr_t      preload_data;
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

  instruction_cache_gm #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) u_icache_gm (
    .clk          (clk),
    .rst_n        (rst_n),
    .preload_en   (preload_en),
    .preload_pc   (preload_pc),
    .preload_data (preload_data),
    .pc0          (pc0),
    .pc1          (pc1),
    .instr0       (ref_instr0),
    .instr1       (ref_instr1)
  );

  function automatic logic [$clog2(SETS)-1:0] idx_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic logic [WAY_AW-1:0] idx_way(input word_t pc);
    return pc[WAY_AW+1:2];
  endfunction

  task automatic preload_slot(input word_t pc, input instr_t word);
    dut.bank[idx_set(pc)][idx_way(pc)] = {1'b1, word[31:0]};
    preload_en   = 1'b1;
    preload_pc   = pc;
    preload_data = word;
    #1;
    preload_en   = 1'b0;
  endtask

  task automatic drive(input word_t pc0_v, input word_t pc1_v);
    pc0 = pc0_v;
    pc1 = pc1_v;
    #1;
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
    forever #5 clk = ~clk;
  end

  initial begin
    string case_name;
    string case_detail;
    word_t pc_a;
    word_t pc_b;

    preload_en = 1'b0;
    pass_cnt = 0;
    fail_cnt = 0;

    clk   = 1'b0;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    tb_banner("instruction_cache_tb — DUT vs instruction_cache_gm.sv");

    imem_load_hex_program(HEX_FILE, prog, prog_len);
    if (prog_len == 0)
      $fatal(1, "instruction_cache_tb: no instructions loaded from %s", HEX_FILE);
    $display("[INFO] Loaded %0d instruction words from %s (base 0x%08h)",
             prog_len, HEX_FILE, prog[0].pc);

    drive(prog[0].pc, prog[0].pc + word_t'(32'd4));
    check_fetch("cold_miss_pair",
                "empty I$ => miss returns 32'h0 on both ports");

    for (int i = 0; i < prog_len; i++)
      preload_slot(prog[i].pc, instr_t'(prog[i].word));

    for (int i = 0; i < prog_len; i++) begin
      pc_a = prog[i].pc;
      case_name   = $sformatf("line_i0_%08h", pc_a);
      case_detail = $sformatf("hex image insn 0x%08h at byte PC 0x%08h on port I0",
                               prog[i].word, pc_a);
      drive(pc_a, pc_a);
      check_fetch(case_name, case_detail);
    end

    for (int i = 0; i < prog_len - 1; i++) begin
      pc_a = prog[i].pc;
      pc_b = prog[i+1].pc;
      case_name   = $sformatf("pair_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("dual fetch sequential pair [%0d/%0d]",
                               i, prog_len - 2);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail);
    end

    drive(prog[0].pc, prog[1].pc);
    check_fetch("repeat_first_pair",
                "re-read first dual-issue pair after line sweep");

    drive(prog[prog_len-2].pc, prog[prog_len-1].pc);
    check_fetch("last_pair",
                "final sequential pair at end of demo program");

    drive(word_t'(32'h0000_2000), word_t'(32'h0000_2004));
    check_fetch("unloaded_miss",
                "address outside hex image => miss 32'h0");

    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "instruction_cache_tb failed");
    $finish;
  end

endmodule
