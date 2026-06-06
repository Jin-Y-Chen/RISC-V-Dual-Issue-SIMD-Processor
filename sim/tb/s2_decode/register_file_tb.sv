`timescale 1ns / 1ps

// register_file_tb - tb.log register_file_tb_20260606 ID read and WB cases, manual expected.
// ID tests: read ports only wen=0, PRE preloaded per test via isolated_reset and preload_gpr.
// WB tests: drive even_wdata and odd_wdata on register_file write ports, manual bus payloads.
// Read addrs: set_reads_dec mirrors decode_pkg rs1 rs2 use policy.
module register_file_tb;

  import rv_dis_pkg::*;
  import decode_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  // Preloaded operand values (ID tests), manual tagged constants
  localparam reg_t PRE_X1  = 32'h0A01_1100;
  localparam reg_t PRE_X2  = 32'h0A02_0002;
  localparam reg_t PRE_X3  = 32'h0A03_0003;
  localparam reg_t PRE_X5  = 32'h0A05_0005;
  localparam reg_t PRE_X6  = 32'h0A06_0006;
  localparam reg_t PRE_X7  = 32'h0A07_0007;
  localparam reg_t PRE_X9  = 32'h0A09_0009;

  // Manual WB bus and PC reference values, tb.log WB and special imm sections
  localparam reg_t PC_BASE         = 32'h0000_1000;
  localparam reg_t EVEN_WPC_0      = 32'd0;
  localparam reg_t ODD_WPC_4       = 32'd4;
  localparam reg_t WB_X2_IMM       = 32'hfa0a_505f;
  localparam reg_t WB_X2_ADDI      = 32'h0000_00aa;
  localparam reg_t WB_X2_LW        = 32'h0000_00bb;
  localparam reg_t ODD_PC          = PC_BASE + 32'd4;
  localparam reg_t WB_JAL_LINK     = PC_BASE + 32'd8;
  localparam reg_t WB_LUI_X7       = 32'h0002_a000;
  localparam reg_t WB_AUIPC_X7     = PC_BASE + 32'h0000_2000;

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

  // Hardware reset, each test starts from empty GPR array (x0 always 0)
  task automatic isolated_reset;
    clear_writes();
    rst_n = 1'b0;
    tick();
    rst_n = 1'b1;
    tick();
    clear_writes();
  endtask

  // One-cycle preload commit (sets operand regs only, not the check under test)
  task automatic preload_gpr(input logic [4:0] rd, input reg_t data);
    if (rd == 5'd0) return;
    drive_writes(1'b1, rd, data, '0, 1'b0, 5'd0, '0, '0);
    tick();
    clear_writes();
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
    $display("  read ports ID");
    tb_field_xreg("even_rs1_addr", even_rs1_addr, exp_e_rs1_addr);
    tb_field_u32 ("even_rs1_data", even_rs1_data, exp_e_rs1_data);
    tb_field_xreg("even_rs2_addr", even_rs2_addr, exp_e_rs2_addr);
    tb_field_u32 ("even_rs2_data", even_rs2_data, exp_e_rs2_data);
    tb_field_xreg("odd_rs1_addr",  odd_rs1_addr,  exp_o_rs1_addr);
    tb_field_u32 ("odd_rs1_data",  odd_rs1_data,  exp_o_rs1_data);
    tb_field_xreg("odd_rs2_addr",  odd_rs2_addr,  exp_o_rs2_addr);
    tb_field_u32 ("odd_rs2_data",  odd_rs2_data,  exp_o_rs2_data);
    $display("  write ports WB");
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

  // Idle lane: addi x0,x0,0 (even), rs1=x0, no WB
  localparam logic [6:0] IDLE_EVEN_OPC = OPC_OP_IMM;
  localparam logic [4:0] IDLE_EVEN_RS1 = 5'd0;
  localparam logic [4:0] IDLE_EVEN_RS2 = 5'd0;

  // Idle lane: lui x0,0 (odd), rs1=0, rd=x0, no WB
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

    isolated_reset();
    tb_banner("register_file_tb - tb.log ID read and WB, manual expected");
    tb_info_msg("Vivado: use Run All or sim time at least 2us to reach summary");

    // =========================================================================
    // Single instruction test cases, ID read only (wen=0), other lane idle
    // =========================================================================
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd2, PRE_X2);
    set_reads_dec(OPC_OP, 5'd5, 5'd2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even R-type",
      rf_detail("add x7,x5,x2, idle odd"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, PRE_X2, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_OP, 5'd5, 5'd6);
    check_rf("single odd R-type",
      rf_detail("idle even, sub x7,x5,x6"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      32'd0, 32'd0, PRE_X5, PRE_X6,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_OP_IMM, 5'd5, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even I-type",
      rf_detail("ori x7,x5,0x2a, idle odd"),
      rf_rs1_addr(OPC_OP_IMM, 5'd5), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_OP_IMM, 5'd5, 5'd0);
    check_rf("single odd I-type",
      rf_detail("idle even, andi x7,x5,0x2b"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_OP_IMM, 5'd5), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      32'd0, 32'd0, PRE_X5, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd9, PRE_X9);
    set_reads_dec(OPC_BRANCH, 5'd7, 5'd9, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even B-type",
      rf_detail("beq x7,x9,label, idle odd"),
      rf_rs1_addr(OPC_BRANCH, 5'd7), rf_rs2_addr(OPC_BRANCH, 5'd9),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X7, PRE_X9, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd1, 5'd5);
    check_rf("single odd B-type",
      rf_detail("idle even, bne x1,x5,label"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_BRANCH, 5'd1), rf_rs2_addr(OPC_BRANCH, 5'd5),
      32'd0, 32'd0, PRE_X1, PRE_X5,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    set_reads_dec(OPC_JAL, 5'd0, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even J-type",
      rf_detail("jal x7,x2, idle odd"),
      rf_rs1_addr(OPC_JAL, 5'd0), rf_rs2_addr(OPC_JAL, 5'd0),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JALR, 5'd6, 5'd0);
    check_rf("single odd J-type",
      rf_detail("idle even, jalr x7,x6,x2"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JALR, 5'd6), rf_rs2_addr(OPC_JALR, 5'd0),
      32'd0, 32'd0, PRE_X6, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_LOAD, 5'd5, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even load",
      rf_detail("lw x7,x2,x5, idle odd"),
      rf_rs1_addr(OPC_LOAD, 5'd5), rf_rs2_addr(OPC_LOAD, 5'd0),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      PRE_X5, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_STORE, 5'd7, 5'd6);
    check_rf("single odd store",
      rf_detail("idle even, sw x7,x2,x6"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_STORE, 5'd7), rf_rs2_addr(OPC_STORE, 5'd6),
      32'd0, 32'd0, PRE_X7, PRE_X6,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    // =========================================================================
    // Dual issue cases without write back, ID read only (wen=0)
    // =========================================================================
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd9, PRE_X9);
    set_reads_dec(OPC_OP_IMM, 5'd5, 5'd0, OPC_OP, 5'd7, 5'd9);
    check_rf("both R-type differnt reads",
      rf_detail("addi x1,x5,0x2c, sll x6,x7,x9, no write back"),
      rf_rs1_addr(OPC_OP_IMM, 5'd5), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(OPC_OP, 5'd7), rf_rs2_addr(OPC_OP, 5'd9),
      PRE_X5, 32'd0, PRE_X7, PRE_X9,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(OPC_OP, 5'd5, 5'd6, OPC_OP, 5'd5, 5'd6);
    check_rf("both R-type same reads",
      rf_detail("or x1,x5,x6, srl x6,x5,x6, no write back"),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      rf_rs1_addr(OPC_OP, 5'd5), rf_rs2_addr(OPC_OP, 5'd6),
      PRE_X5, PRE_X6, PRE_X5, PRE_X6,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd9, PRE_X9);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_OP, 5'd7, 5'd9, OPC_LOAD, 5'd5, 5'd0);
    check_rf("ideal case different reads",
      rf_detail("sub x6,x7,x9, lw x1,0(x5), no write back"),
      rf_rs1_addr(OPC_OP, 5'd7), rf_rs2_addr(OPC_OP, 5'd9),
      rf_rs1_addr(OPC_LOAD, 5'd5), rf_rs2_addr(OPC_LOAD, 5'd0),
      PRE_X7, PRE_X9, PRE_X5, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd9, PRE_X9);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(OPC_STORE, 5'd9, 5'd6, OPC_OP_IMM, 5'd9, 5'd0);
    check_rf("ideal case same reads",
      rf_detail("sw x6,0(x9), ori x1,x9,0x2d, no write back"),
      rf_rs1_addr(OPC_STORE, 5'd9), rf_rs2_addr(OPC_STORE, 5'd6),
      rf_rs1_addr(OPC_OP_IMM, 5'd9), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      PRE_X9, PRE_X6, PRE_X9, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    preload_gpr(5'd7, PRE_X7);
    set_reads_dec(OPC_BRANCH, 5'd1, 5'd5, OPC_BRANCH, 5'd6, 5'd7);
    check_rf("both B-type different reads",
      rf_detail("blt x1,x5,label, bge x6,x7,label"),
      rf_rs1_addr(OPC_BRANCH, 5'd1), rf_rs2_addr(OPC_BRANCH, 5'd5),
      rf_rs1_addr(OPC_BRANCH, 5'd6), rf_rs2_addr(OPC_BRANCH, 5'd7),
      PRE_X1, PRE_X5, PRE_X6, PRE_X7,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_BRANCH, 5'd1, 5'd5, OPC_BRANCH, 5'd1, 5'd5);
    check_rf("both B-type same reads",
      rf_detail("beq x1,x5,label, bne x1,x5,label"),
      rf_rs1_addr(OPC_BRANCH, 5'd1), rf_rs2_addr(OPC_BRANCH, 5'd5),
      rf_rs1_addr(OPC_BRANCH, 5'd1), rf_rs2_addr(OPC_BRANCH, 5'd5),
      PRE_X1, PRE_X5, PRE_X1, PRE_X5,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b0, 5'd0, 32'd0, 32'd0);
    // =========================================================================
    // Dual issue cases with write back, even lane ALU imm or reg results
    // =========================================================================
    isolated_reset();
    drive_writes(1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, '0, '0);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB addi x2 imm",
      rf_detail("addi x2,x1,0xfa0a505f, even_rd x2, even_wdata 0xfa0a505f"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    drive_writes(1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, '0, '0);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB add x2 reg",
      rf_detail("add x2,x1,x3, even_rd x2, even_wdata 0xfa0a505f"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(IDLE_ODD_OPC, IDLE_ODD_RS1), rf_rs2_addr(IDLE_ODD_OPC, IDLE_ODD_RS2),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, 32'd0, 32'd0);
    isolated_reset();
    drive_writes(1'b1, 5'd2, WB_X2_ADDI, EVEN_WPC_0, 1'b1, 5'd2, WB_X2_LW, ODD_WPC_4);
    set_reads_dec(OPC_OP_IMM, 5'd0, 5'd0, OPC_LOAD, 5'd2, 5'd0);
    check_rf("WB merge addi lw x2",
      rf_detail("addi x2,x1,0xaa, lw x2,0(x2), odd wpc wins on x2"),
      rf_rs1_addr(OPC_OP_IMM, 5'd0), rf_rs2_addr(OPC_OP_IMM, 5'd0),
      rf_rs1_addr(OPC_LOAD, 5'd2), rf_rs2_addr(OPC_LOAD, 5'd0),
      32'd0, 32'd0, WB_X2_LW, 32'd0,
      1'b1, 5'd2, WB_X2_ADDI, EVEN_WPC_0,
      1'b1, 5'd2, WB_X2_LW, ODD_WPC_4);
    // =========================================================================
    // Special PC and immediate write back, odd lane only (branch jump lui auipc)
    // =========================================================================
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JAL, 5'd0, 5'd0);
    check_rf("WB jal odd",
      rf_detail("idle even, jal x7,x2, odd rd x7, odd_wdata PC plus 4"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JAL, 5'd0), rf_rs2_addr(OPC_JAL, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JALR, 5'd6, 5'd0);
    check_rf("WB jalr odd",
      rf_detail("idle even, jalr x7,x6,x2, odd rd x7, odd_wdata PC plus 4"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_JALR, 5'd6), rf_rs2_addr(OPC_JALR, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_LUI_X7, ODD_PC);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_LUI, 5'd0, 5'd0);
    check_rf("WB lui odd",
      rf_detail("idle even, lui x7,0x2a, odd rd x7, odd_wdata imm shift 12"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_LUI, 5'd0), rf_rs2_addr(OPC_LUI, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd7, WB_LUI_X7, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_AUIPC_X7, ODD_PC);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_AUIPC, 5'd0, 5'd0);
    check_rf("WB auipc odd",
      rf_detail("idle even, auipc x7,0x2, odd rd x7, odd_wdata PC plus imm shift 12"),
      rf_rs1_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS1), rf_rs2_addr(IDLE_EVEN_OPC, IDLE_EVEN_RS2),
      rf_rs1_addr(OPC_AUIPC, 5'd0), rf_rs2_addr(OPC_AUIPC, 5'd0),
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, 5'd0, 32'd0, 32'd0, 1'b1, 5'd7, WB_AUIPC_X7, ODD_PC);
    if (fail_cnt != 0)
      $fatal(1, "register_file_tb failed");
    $finish;
  end

  final begin
    $display("");
    tb_summary(pass_cnt, fail_cnt);
  end

endmodule