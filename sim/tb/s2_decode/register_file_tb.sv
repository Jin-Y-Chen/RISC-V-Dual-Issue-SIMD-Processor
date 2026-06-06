`timescale 1ns / 1ps

// register_file_tb — isolated per-instruction GPR checks (demo_instructions.asm mnemonics).
// ID tests: read ports only (wen=0); isolated_reset preloads x1,x5,x6,x7,x9 (x10 per-test).
// WB tests: drive even_wdata/odd_wdata (32-bit WB data ports on register_file.sv); manual
//   D0xx_.... payloads — TB stimulus on the write bus, not ALU/LUI decode (≠ asm imm in detail).
// Read addrs: set_reads_dec() mirrors decode_pkg / decoder_tb rs1/rs2 policy.
module register_file_tb;

  import rv_dis_pkg::*;
  import decode_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  // Preloaded operand values (ID tests) — tagged constants, not asm immediates
  localparam reg_t PRE_X1  = 32'h0A01_1100;
  localparam reg_t PRE_X5  = 32'h0A05_0005;
  localparam reg_t PRE_X6  = 32'h0A06_0006;
  localparam reg_t PRE_X7  = 32'h0A07_0007;
  localparam reg_t PRE_X9  = 32'h0A09_0009;
  localparam reg_t PRE_X10 = 32'h0A10_1000;

  // 32-bit WB data port payloads (even_wdata / odd_wdata) — D0rd_.... manual bus values
  localparam reg_t WB_X5       = 32'hD005_000A;
  localparam reg_t WB_X7       = 32'hD007_001E;
  localparam reg_t WB_X10_LUI  = 32'hD010_1000;
  localparam reg_t WB_X11_EV   = 32'hD011_00AA;
  localparam reg_t WB_X11_OD   = 32'hD011_2000;
  localparam reg_t WB_X13      = 32'hD013_1008;
  localparam reg_t WB_X14      = 32'hD014_0004;
  localparam reg_t WB_X16_EV   = 32'hD016_0001;
  localparam reg_t WB_X16_OD   = 32'hD016_1000;
  localparam reg_t WB_LW_X11   = 32'hD011_0014;
  localparam reg_t WB_X11_ADDI = 32'hD011_0011;
  localparam reg_t WB_JAL_X1   = 32'hD001_1100;
  localparam reg_t WB_ADDI_X2  = 32'hD002_002A;
  localparam reg_t WB_X0_DEAD  = 32'hDEAD_BEEF;

  logic        clk;
  logic        rst_n;

  logic [4:0]  even_rs1_addr;
  logic [4:0]  even_rs2_addr;
  reg_t        even_rs1_data;
  reg_t        even_rs2_data;

  logic [4:0]  odd_rs1_addr;
  logic [4:0]  odd_rs2_addr;
  reg_t        odd_rs1_data;
  reg_t        odd_rs2_data;

  logic        even_wen;
  logic [4:0]  even_rd;
  reg_t        even_wdata;
  reg_t        even_wpc;

  logic        odd_wen;
  logic [4:0]  odd_rd;
  reg_t        odd_wdata;
  reg_t        odd_wpc;

  int pass_cnt;
  int fail_cnt;

  register_file dut (.*);

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic clear_writes;
    even_wen   = 1'b0;
    odd_wen    = 1'b0;
    even_rd    = 5'd0;
    odd_rd     = 5'd0;
    even_wdata = '0;
    odd_wdata  = '0;
    even_wpc   = '0;
    odd_wpc    = '0;
  endtask

  task automatic set_reads(
    input logic [4:0] e_rs1,
    input logic [4:0] e_rs2,
    input logic [4:0] o_rs1,
    input logic [4:0] o_rs2
  );
    even_rs1_addr = e_rs1;
    even_rs2_addr = e_rs2;
    odd_rs1_addr  = o_rs1;
    odd_rs2_addr  = o_rs2;
    #1;
  endtask

  function automatic logic [4:0] rf_rs1_addr(
    input logic [6:0] opcode,
    input logic [4:0] rs1_field
  );
    unique case (opcode)
      OPC_LUI, OPC_AUIPC, OPC_JAL: rf_rs1_addr = 5'd0;
      default: rf_rs1_addr = decode_rs1_use(opcode) ? rs1_field : 5'd0;
    endcase
  endfunction

  function automatic logic [4:0] rf_rs2_addr(
    input logic [6:0] opcode,
    input logic [4:0] rs2_field
  );
    rf_rs2_addr = decode_rs2_use(opcode) ? rs2_field : 5'd0;
  endfunction

  task automatic set_reads_dec(
    input logic [6:0] e_opc,
    input logic [4:0] e_rs1_f,
    input logic [4:0] e_rs2_f,
    input logic [6:0] o_opc,
    input logic [4:0] o_rs1_f,
    input logic [4:0] o_rs2_f
  );
    set_reads(rf_rs1_addr(e_opc, e_rs1_f), rf_rs2_addr(e_opc, e_rs2_f),
              rf_rs1_addr(o_opc, o_rs1_f), rf_rs2_addr(o_opc, o_rs2_f));
  endtask

  task automatic drive_writes(
    input logic        e_wen,
    input logic [4:0]  e_rd,
    input reg_t        e_wdata,
    input reg_t        e_wpc,
    input logic        o_wen,
    input logic [4:0]  o_rd,
    input reg_t        o_wdata,
    input reg_t        o_wpc
  );
    even_wen   = e_wen;
    even_rd    = e_rd;
    even_wdata = e_wdata;
    even_wpc   = e_wpc;
    odd_wen    = o_wen;
    odd_rd     = o_rd;
    odd_wdata  = o_wdata;
    odd_wpc    = o_wpc;
  endtask

  task automatic isolated_reset_bare;
    clear_writes();
    rst_n = 1'b0;
    tick();
    rst_n = 1'b1;
    tick();
    clear_writes();
  endtask

  task automatic preload_gpr(input logic [4:0] rd, input reg_t data);
    if (rd == 5'd0) return;
    drive_writes(1'b1, rd, data, '0, 1'b0, 5'd0, '0, '0);
    tick();
    clear_writes();
  endtask

  task automatic isolated_reset;
    isolated_reset_bare();
    drive_writes(1'b1, 5'd1, PRE_X1, '0, 1'b1, 5'd5, PRE_X5, '0); tick(); clear_writes();
    drive_writes(1'b1, 5'd6, PRE_X6, '0, 1'b1, 5'd7, PRE_X7, '0); tick(); clear_writes();
    preload_gpr(5'd9, PRE_X9);
  endtask

  task automatic tb_field_xreg(input string label, input logic [4:0] got, input logic [4:0] exp);
    tb_field_line(label, $sformatf("x%0d", got), $sformatf("x%0d", exp));
  endtask

  task automatic check_rf(
    input string      name,
    input string      detail,
    input logic [4:0] exp_e_rs1_addr,
    input logic [4:0] exp_e_rs2_addr,
    input logic [4:0] exp_o_rs1_addr,
    input logic [4:0] exp_o_rs2_addr,
    input reg_t       exp_e_rs1_data,
    input reg_t       exp_e_rs2_data,
    input reg_t       exp_o_rs1_data,
    input reg_t       exp_o_rs2_data,
    input logic       exp_even_wen,
    input logic [4:0] exp_even_rd,
    input reg_t       exp_even_wdata,
    input reg_t       exp_even_wpc,
    input logic       exp_odd_wen,
    input logic [4:0] exp_odd_rd,
    input reg_t       exp_odd_wdata,
    input reg_t       exp_odd_wpc
  );
    bit pass;
    pass = (even_rs1_addr === exp_e_rs1_addr) && (even_rs2_addr === exp_e_rs2_addr) &&
           (odd_rs1_addr  === exp_o_rs1_addr)  && (odd_rs2_addr  === exp_o_rs2_addr)  &&
           (even_rs1_data === exp_e_rs1_data) && (even_rs2_data === exp_e_rs2_data) &&
           (odd_rs1_data  === exp_o_rs1_data)  && (odd_rs2_data  === exp_o_rs2_data)  &&
           (even_wen      === exp_even_wen)    && (even_rd       === exp_even_rd)    &&
           (even_wdata    === exp_even_wdata)  && (even_wpc      === exp_even_wpc)    &&
           (odd_wen       === exp_odd_wen)     && (odd_rd        === exp_odd_rd)     &&
           (odd_wdata     === exp_odd_wdata)   && (odd_wpc       === exp_odd_wpc);
    tb_report_open(pass, name, detail);
    $display("  --- read ports (ID) ---");
    tb_field_xreg("even_rs1_addr", even_rs1_addr, exp_e_rs1_addr);
    tb_field_u32 ("even_rs1_data", even_rs1_data, exp_e_rs1_data);
    tb_field_xreg("even_rs2_addr", even_rs2_addr, exp_e_rs2_addr);
    tb_field_u32 ("even_rs2_data", even_rs2_data, exp_e_rs2_data);
    tb_field_xreg("odd_rs1_addr",  odd_rs1_addr,  exp_o_rs1_addr);
    tb_field_u32 ("odd_rs1_data",  odd_rs1_data,  exp_o_rs1_data);
    tb_field_xreg("odd_rs2_addr",  odd_rs2_addr,  exp_o_rs2_addr);
    tb_field_u32 ("odd_rs2_data",  odd_rs2_data,  exp_o_rs2_data);
    $display("  --- write ports (WB) ---");
    tb_field_bit ("even_wen",      even_wen,      exp_even_wen);
    tb_field_xreg("even_rd",       even_rd,       exp_even_rd);
    tb_field_u32 ("even_wdata",    even_wdata,    exp_even_wdata);
    tb_field_u32 ("even_wpc",      even_wpc,      exp_even_wpc);
    tb_field_bit ("odd_wen",       odd_wen,       exp_odd_wen);
    tb_field_xreg("odd_rd",        odd_rd,        exp_odd_rd);
    tb_field_u32 ("odd_wdata",     odd_wdata,     exp_odd_wdata);
    tb_field_u32 ("odd_wpc",       odd_wpc,       exp_odd_wpc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  function automatic string rf_detail(input string asm);
    return asm;
  endfunction

  // Idle lane: addi x0,x0,0 (even) — rs1=x0, no WB
  localparam logic [6:0] IDLE_EVEN_OPC = OPC_OP_IMM;
  localparam logic [4:0] IDLE_EVEN_RS1 = 5'd0;
  localparam logic [4:0] IDLE_EVEN_RS2 = 5'd0;

  // Idle lane: lui x0,0 (odd) — rs1=0, rd=x0, no WB
  localparam logic [6:0] IDLE_ODD_OPC  = OPC_LUI;
  localparam logic [4:0] IDLE_ODD_RS1  = 5'd0;
  localparam logic [4:0] IDLE_ODD_RS2  = 5'd0;

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    even_rs1_addr = 5'd0;
    even_rs2_addr = 5'd0;
    odd_rs1_addr  = 5'd0;
    odd_rs2_addr  = 5'd0;
    clear_writes();

    isolated_reset_bare();
    tb_banner("register_file_tb - isolated insn (ID read + WB), manual expected");
    tb_info_msg($sformatf("GPR defaults (isolated_reset): x1=%08h x5=%08h x6=%08h x7=%08h x9=%08h",
                          PRE_X1, PRE_X5, PRE_X6, PRE_X7, PRE_X9));

    // =========================================================================
    // ID read-only — even lane (demo even mnemonics), odd idle, wen=0
    // =========================================================================
    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_add",
      rf_detail("add x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP_IMM, 5'd0, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_addi",
      rf_detail("addi x5,x0,10 | (idle odd)"),
      rf_rs1_addr(OPC_OP_IMM, 5'd0), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd6, 5'd5, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_sub",
      rf_detail("sub x7,x6,x5 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd6), rf_rs2_addr(OPC_OP, 5'd5),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X6, PRE_X5, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_sll",
      rf_detail("sll x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_slt",
      rf_detail("slt x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_xor",
      rf_detail("xor x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd6, 5'd5, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_srl",
      rf_detail("srl x7,x6,x5 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd6), rf_rs2_addr(OPC_OP, 5'd5),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X6, PRE_X5, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd6, 5'd5, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_sra",
      rf_detail("sra x7,x6,x5 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd6), rf_rs2_addr(OPC_OP, 5'd5),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X6, PRE_X5, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_or",
      rf_detail("or x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_and",
      rf_detail("and x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(OPC_OP, 5'd0, 5'd5, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("id_even_add_x0_rs1",
      rf_detail("add x7,x0,x5 | (idle odd) — x0 read"),
      rf_rs1_addr(OPC_OP, 5'd0), rf_rs2_addr(OPC_OP, 5'd5),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, PRE_X5, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    // =========================================================================
    // ID read-only — odd lane (demo odd mnemonics), even idle, wen=0
    // =========================================================================
    isolated_reset();
    preload_gpr(5'd10, PRE_X10);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_LOAD, 5'd10, 5'd0);
    check_rf("id_odd_lw",
      rf_detail("(idle even) | lw x9,0(x10)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_LOAD, 5'd10), rf_rs2_addr(OPC_LOAD, 5'd0),
      32'd0, 32'd0, PRE_X10, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    preload_gpr(5'd10, PRE_X10);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_STORE, 5'd10, 5'd7);
    check_rf("id_odd_sw",
      rf_detail("(idle even) | sw x7,0(x10)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_STORE, 5'd10), rf_rs2_addr(OPC_STORE, 5'd7),
      32'd0, 32'd0, PRE_X10, PRE_X7,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd5, 5'd0);
    check_rf("id_odd_beq",
      rf_detail("(idle even) | beq x5,x0,label"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_BRANCH, 5'd5), rf_rs2_addr(OPC_BRANCH, 5'd0),
      32'd0, 32'd0, PRE_X5, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd5, 5'd0);
    check_rf("id_odd_bne",
      rf_detail("(idle even) | bne x5,x0,label"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_BRANCH, 5'd5), rf_rs2_addr(OPC_BRANCH, 5'd0),
      32'd0, 32'd0, PRE_X5, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd6, 5'd5);
    check_rf("id_odd_blt",
      rf_detail("(idle even) | blt x6,x5,label"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_BRANCH, 5'd6), rf_rs2_addr(OPC_BRANCH, 5'd5),
      32'd0, 32'd0, PRE_X6, PRE_X5,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd6, 5'd5);
    check_rf("id_odd_bge",
      rf_detail("(idle even) | bge x6,x5,label"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_BRANCH, 5'd6), rf_rs2_addr(OPC_BRANCH, 5'd5),
      32'd0, 32'd0, PRE_X6, PRE_X5,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JAL, 5'd0, 5'd0);
    check_rf("id_odd_jal",
      rf_detail("(idle even) | jal x1,helper"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JAL, 5'd0), rf_rs2_addr(OPC_JAL, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JALR, 5'd1, 5'd0);
    check_rf("id_odd_jalr",
      rf_detail("(idle even) | jalr x0,0(x1)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JALR, 5'd1), rf_rs2_addr(OPC_JALR, 5'd0),
      32'd0, 32'd0, PRE_X1, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_LUI, 5'd0, 5'd0);
    check_rf("id_odd_lui",
      rf_detail("(idle even) | lui x10,0x1"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_LUI, 5'd0), rf_rs2_addr(OPC_LUI, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_AUIPC, 5'd0, 5'd0);
    check_rf("id_odd_auipc",
      rf_detail("(idle even) | auipc x13,0"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_AUIPC, 5'd0), rf_rs2_addr(OPC_AUIPC, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    // =========================================================================
    // WB — single instruction writeback (other lane idle), manual expected
    // =========================================================================
    isolated_reset();
    drive_writes(1'b1, 5'd5, WB_X5, 32'h1004, 1'b0, 5'd0, '0, '0);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("wb_even_addi_x5",
      rf_detail("WB: addi x5,x0,10 | (idle odd)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd5, WB_X5, 32'h1004, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd10, WB_X10_LUI, 32'h1000);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("wb_odd_lui_x10",
      rf_detail("(idle even) | WB: lui x10,0x1"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd10, WB_X10_LUI, 32'h1000);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd13, WB_X13, 32'h1008);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("wb_odd_auipc_x13",
      rf_detail("(idle even) | WB: auipc x13,0"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd13, WB_X13, 32'h1008);
    tick(); clear_writes();

    isolated_reset();
    preload_gpr(5'd10, PRE_X10);
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd11, WB_LW_X11, 32'h103C);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_LOAD, 5'd10, 5'd0);
    check_rf("wb_odd_lw_x11",
      rf_detail("(idle even) | WB: lw x11,0(x10)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_LOAD, 5'd10), rf_rs2_addr(OPC_LOAD, 5'd0),
      32'd0, 32'd0, PRE_X10, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd11, WB_LW_X11, 32'h103C);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd1, WB_JAL_X1, 32'h10FC);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JAL, 5'd0, 5'd0);
    check_rf("wb_odd_jal_x1",
      rf_detail("(idle even) | WB: jal x1,helper"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JAL, 5'd0), rf_rs2_addr(OPC_JAL, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd1, WB_JAL_X1, 32'h10FC);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b1, 5'd2, WB_ADDI_X2, 32'h1118, 1'b0, 5'd0, '0, '0);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("wb_even_addi_x2",
      rf_detail("WB: addi x2,x0,42 | (idle odd)"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd2, WB_ADDI_X2, 32'h1118, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b1, 5'd7, WB_X7, 32'h1010, 1'b0, 5'd0, '0, '0);
    set_reads_dec(OPC_OP, 5'd5, 5'd6, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("wb_even_add_x7",
      rf_detail("WB: add x7,x5,x6 | (idle odd)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X6, 32'd0, 32'd0,
      1'b1, 5'd7, WB_X7, 32'h1010, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    // =========================================================================
    // WB — RF policy (outline §5): merge, bypass, x0, multi-read
    // =========================================================================
    isolated_reset();
    drive_writes(1'b1, 5'd11, WB_X11_EV, 32'h1028, 1'b1, 5'd11, WB_X11_OD, 32'h102C);
    set_reads_dec(OPC_OP_IMM, 5'd0, 5'd0, OPC_LUI, 5'd0, 5'd0);
    check_rf("wb_merge_addi_lui_x11",
      rf_detail("WB: addi x11,x0,0xAA | WB: lui x11,0x2 (odd wpc wins)"),
      rf_rs1_addr(OPC_OP_IMM, 5'd0), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(OPC_LUI, 5'd0), rf_rs2_addr(OPC_LUI, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd11, WB_X11_EV, 32'h1028,
      1'b1, 5'd11, WB_X11_OD, 32'h102C);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b1, 5'd14, WB_X14, 32'h1048, 1'b0, 5'd0, '0, '0);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_LOAD, 5'd14, 5'd0);
    check_rf("wb_bypass_addi_lw_x14",
      rf_detail("WB: addi x14,x0,4 | lw x15,0(x14) — odd rs1 bypass"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_LOAD, 5'd14), rf_rs2_addr(OPC_LOAD, 5'd0),
      32'd0, 32'd0, WB_X14, 32'd0,
      1'b1, 5'd14, WB_X14, 32'h1048, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    drive_writes(1'b1, 5'd16, WB_X16_EV, 32'h1050, 1'b1, 5'd16, WB_X16_OD, 32'h1054);
    set_reads_dec(OPC_OP_IMM, 5'd0, 5'd0, OPC_LUI, 5'd0, 5'd0);
    check_rf("wb_merge_addi_lui_x16",
      rf_detail("WB: addi x16,x0,1 | WB: lui x16,0x1 (odd wins)"),
      rf_rs1_addr(OPC_OP_IMM, 5'd0), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(OPC_LUI, 5'd0), rf_rs2_addr(OPC_LUI, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd16, WB_X16_EV, 32'h1050,
      1'b1, 5'd16, WB_X16_OD, 32'h1054);
    tick(); clear_writes();

    isolated_reset();
    preload_gpr(5'd10, PRE_X10);
    drive_writes(1'b1, 5'd0, WB_X0_DEAD, 32'h1058, 1'b0, 5'd0, '0, '0);
    set_reads_dec(OPC_OP, 5'd5, 5'd6, OPC_STORE, 5'd10, 5'd6);
    check_rf("wb_even_add_x0_ignore",
      rf_detail("WB: add x0,x5,x6 (ignored) | sw x6,8(x10)"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(OPC_STORE, 5'd10), rf_rs2_addr(OPC_STORE, 5'd6),
      PRE_X5, PRE_X6, PRE_X10, PRE_X6,
      1'b0, 5'd0, WB_X0_DEAD, 32'h1058, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset();
    preload_gpr(5'd10, PRE_X10);
    drive_writes(1'b1, 5'd7, WB_X7, 32'h1010, 1'b0, 5'd0, '0, '0);
    set_reads_dec(OPC_OP, 5'd5, 5'd5, OPC_STORE, 5'd10, 5'd7);
    check_rf("wb_multi_read_x5_x7",
      rf_detail("WB: add x7,x5,x5 | sw x7,0(x10) — x5×2 + x7 bypass"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd5),
      rf_rs1_addr(OPC_STORE, 5'd10), rf_rs2_addr(OPC_STORE, 5'd7),
      PRE_X5, PRE_X5, PRE_X10, WB_X7,
      1'b1, 5'd7, WB_X7, 32'h1010, 1'b0, 5'd0, 32'd0, 32'd0);
    tick(); clear_writes();

    isolated_reset_bare();
    drive_writes(1'b1, 5'd11, WB_X11_ADDI, 32'h1038, 1'b1, 5'd11, WB_LW_X11, 32'h103C);
    set_reads_dec(OPC_OP_IMM, 5'd0, 5'd0, OPC_LOAD, 5'd10, 5'd0);
    check_rf("wb_merge_addi_lw_x11",
      rf_detail("WB: addi x11,x0,17 | WB: lw x11,0(x10) (odd wins)"),
      rf_rs1_addr(OPC_OP_IMM, 5'd0), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(OPC_LOAD, 5'd10), rf_rs2_addr(OPC_LOAD, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd11, WB_X11_ADDI, 32'h1038,
      1'b1, 5'd11, WB_LW_X11, 32'h103C);
    tick(); clear_writes();

    // Required footer for copy_logs.ps1 → summary.txt (*** SUMMARY: N passed, 0 failed - OK ***)
    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "register_file_tb failed");
    $finish;
  end

endmodule
