`timescale 1ns / 1ps

// instruction_cache_tb - dual fetch vs gm; preload .mem into 2-way I$ bank.
// Geometry: INDEX_W=13, WAYS=2, SETS=4096; each entry = valid + 4-byte ILEN word.
// Vectors: i0/i1 solo, mode=1 split (pc,pc+4), mode=0 bundle (pc+8,pc+12); posedge.
// Vivado: +imem_mem=<path>; optional +cache_dump=<path> writes valid bank lines.
import rv_dis_pkg::*;
import imem_hex_loader_pkg::*;

`include "../include/tb_console.svh"

module instruction_cache_tb;

  localparam int INDEX_W = PC_INDEX_AW;
  localparam int WAYS    = 2;
  localparam int WAY_AW  = $clog2(WAYS);
  localparam int SETS    = (1 << INDEX_W) / WAYS;
  localparam int BYTES_PER_ENTRY = ILEN / ADDR_UNIT_BITS;  // 4

  localparam string MEM_FILE_DEFAULT = "demo_instructions.mem";
  localparam int    CLK_PERIOD       = 10;
  localparam word_t MISS_PC          = 32'h0000_2000;

  logic        clk;
  logic        rst_n;
  logic [31:0] pc0;
  logic [31:0] pc1;
  logic [31:0] instr0;
  logic [31:0] instr1;
  logic        i0_valid;
  logic        i1_valid;
  instr_t      ref_instr0;
  instr_t      ref_instr1;
  logic        ref_i0_valid;
  logic        ref_i1_valid;

  imem_prog_entry_t prog [256];
  int               prog_len;

  int pass_cnt;
  int fail_cnt;

  instruction_cache #(
    .INDEX_W(INDEX_W),
    .WAYS   (WAYS)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .pc0      (pc0),
    .pc1      (pc1),
    .instr0   (instr0),
    .instr1   (instr1),
    .i0_valid (i0_valid),
    .i1_valid (i1_valid)
  );

  instruction_cache_gm u_icache_gm (
    .pc0      (pc0),
    .pc1      (pc1),
    .instr0   (ref_instr0),
    .instr1   (ref_instr1),
    .i0_valid (ref_i0_valid),
    .i1_valid (ref_i1_valid)
  );

  function automatic logic [$clog2(SETS)-1:0] idx_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic logic [WAY_AW-1:0] idx_way(input word_t pc);
    return pc[WAY_AW+1:2];
  endfunction

  task automatic preload_slot(input word_t pc, input instr_t word);
    // Install one 4-byte ILEN word at the PC's set/way (valid=1).
    dut.bank[idx_set(pc)][idx_way(pc)] = {1'b1, word[31:0]};
  endtask

  task automatic dump_cache_txt(input string path);
    int fd;
    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("dump_cache_txt: cannot open %s", path);
      return;
    end
    $fdisplay(fd, "# instruction_cache DUT bank (valid entries only)");
    $fdisplay(fd, "# INDEX_W=%0d WAYS=%0d SETS=%0d BYTES_PER_ENTRY=%0d",
              INDEX_W, WAYS, SETS, BYTES_PER_ENTRY);
    $fdisplay(fd, "# columns: set way instr_word");
    for (int s = 0; s < SETS; s++)
      for (int w = 0; w < WAYS; w++)
        if (dut.bank[s][w][32])
          $fdisplay(fd, "%4d %2d 0x%08h", s, w, dut.bank[s][w][31:0]);
    $fclose(fd);
    $display("[INFO] cache dump -> %s", path);
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
    pass = (instr0 === 32'h0) && (instr1 === 32'h0)
        && (i0_valid === 1'b0) && (i1_valid === 1'b0);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("pc0", pc0);
    tb_field_in_u32("pc1", pc1);
    $display("");
    tb_log_section("check");
    tb_field_u32("instr0", instr0, 32'h0);
    tb_field_u32("instr1", instr1, 32'h0);
    tb_field_bit("i0_valid", i0_valid, 1'b0);
    tb_field_bit("i1_valid", i1_valid, 1'b0);
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
    pass = (instr0 === ref_instr0) && (instr1 === ref_instr1)
        && (i0_valid === ref_i0_valid) && (i1_valid === ref_i1_valid);
    tb_report_open(pass, name, detail);
    tb_log_section("inputs");
    tb_field_in_u32("pc0", pc0);
    tb_field_in_u32("pc1", pc1);
    $display("");
    tb_log_section("check");
    tb_field_u32("instr0", instr0, ref_instr0);
    tb_field_u32("instr1", instr1, ref_instr1);
    tb_field_bit("i0_valid", i0_valid, ref_i0_valid);
    tb_field_bit("i1_valid", i1_valid, ref_i1_valid);
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

    // Port I0 only - I1 at inactive miss address (pc0 != pc1).
    for (int i = 0; i < prog_len; i++) begin
      pc_a = prog[i].pc;
      case_name   = $sformatf("i0_only_%08h", pc_a);
      case_detail = $sformatf("I0 hit @0x%08h; I1 inactive @0x%08h", pc_a, MISS_PC);
      drive(pc_a, MISS_PC);
      check_fetch(case_name, case_detail);
    end

    // Port I1 only - I0 at inactive miss address.
    for (int i = 0; i < prog_len; i++) begin
      pc_a = prog[i].pc;
      case_name   = $sformatf("i1_only_%08h", pc_a);
      case_detail = $sformatf("I0 inactive @0x%08h; I1 hit @0x%08h", MISS_PC, pc_a);
      drive(MISS_PC, pc_a);
      check_fetch(case_name, case_detail);
    end

    // mode=1 speculative / split: pc0=pc, pc1=pc+4 (divergent pc0_in/pc1_in; +4 step)
    for (int i = 0; i < prog_len - 1; i++) begin
      pc_a = prog[i].pc;
      pc_b = pc_a + word_t'(32'd4);
      case_name   = $sformatf("spec_delta4_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("mode=1 split pair [%0d/%0d]", i, prog_len - 2);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail);
    end

    // mode=0 sequential dual-issue: (pc0,pc1)+8 -> e.g. 1000,1004 then 1008,100c
    for (int i = 0; i < prog_len - 3; i++) begin
      pc_a = prog[i].pc + word_t'(32'd8);
      pc_b = prog[i].pc + word_t'(32'd12);
      case_name   = $sformatf("seq_delta8_%08h_%08h", pc_a, pc_b);
      case_detail = $sformatf("mode=0 +8 bundle from base 0x%08h [%0d/%0d]",
                              prog[i].pc, i, prog_len - 4);
      drive(pc_a, pc_b);
      check_fetch(case_name, case_detail);
    end

    drive(prog[0].pc, prog[0].pc + word_t'(32'd4));
    check_fetch("repeat_first_spec_delta4",
                "re-read first mode=1 split pair after sweeps");

    drive(prog[prog_len-2].pc, prog[prog_len-1].pc);
    check_fetch("last_spec_delta4",
                "final mode=1 split pair at end of demo program");

    drive(MISS_PC, MISS_PC + word_t'(32'd4));
    check_fetch("unloaded_miss_spec_delta4",
                "both ports miss outside demo .mem image => 32'h0");

    if ($test$plusargs("cache_dump")) begin
      string dump_path;
      dump_path = "icache_bank.txt";
      void'($value$plusargs("cache_dump=%s", dump_path));
      dump_cache_txt(dump_path);
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $error("instruction_cache_tb: %0d failure(s)", fail_cnt);
    $finish;
  end

endmodule
