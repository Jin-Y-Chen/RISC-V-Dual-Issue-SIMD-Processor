`timescale 1ns / 1ps

// register_file_tb - tb.log register_file_tb_20260606 ID read and WB cases, manual expected.
// ID tests: read ports only wen=0, PRE preloaded per test via isolated_reset and preload_gpr.
//   Operand reads stay active per decoded rs1/rs2; idle lane only is all zero.
//   Same-rd WB merge suppresses older commit only, not ID operand reads (addi still reads rs1).
// WB tests: same cycle has 2 insns in WB (even/odd write) and 2 insns in ID (even/odd read).
//   An insn is in WB or ID, never both. ID reads may bypass WB rd (same or cross lane).
// check_rf exp args are literal golden values only, never DUT outputs or rf_rs1_addr helpers.
// set_reads_dec uses decode_pkg for stimulus addr mux policy only.
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
  // Odd-lane insn PC (I1 = PC_BASE+4); wpc on WB bus is this latched PC
  localparam reg_t ODD_PC          = PC_BASE + 32'd4;
  // jal/jalr Green Card: R[rd] = PC+4 (link only on odd_wdata; PC jump not on GPR bus)
  localparam reg_t WB_JAL_LINK     = ODD_PC + 32'd4;
  // lui x7,0x2a: R[rd] = imm<<12
  localparam reg_t LUI_IMM_2A      = 32'h0000_002a;
  localparam reg_t WB_LUI_X7       = LUI_IMM_2A << 12;
  // auipc x7,0x2: R[rd] = PC + (imm<<12)
  localparam reg_t AUIPC_IMM_2     = 32'h0000_0002;
  localparam reg_t WB_AUIPC_X7     = ODD_PC + (AUIPC_IMM_2 << 12);

  // Manual immediates for log mnemonics (jal/jalr/load/store offset fields)
  localparam reg_t JAL_IMM_0   = 32'h0000_0000;
  localparam reg_t JALR_IMM_0  = 32'h0000_0000;
  localparam reg_t LOAD_IMM_0  = 32'h0000_0000;
  localparam reg_t STORE_IMM_0 = 32'h0000_0000;

  // Manual golden read addresses for check_rf exp, independent of decode helpers
  localparam logic [4:0] ADDR_X0 = 5'd0;
  localparam logic [4:0] ADDR_X1 = 5'd1;
  localparam logic [4:0] ADDR_X2 = 5'd2;
  localparam logic [4:0] ADDR_X3 = 5'd3;
  localparam logic [4:0] ADDR_X5 = 5'd5;
  localparam logic [4:0] ADDR_X6 = 5'd6;
  localparam logic [4:0] ADDR_X7 = 5'd7;
  localparam logic [4:0] ADDR_X9 = 5'd9;

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

  // rf_detail mnemonics: immediates/offsets as 0x.. hex, not labels or bare decimals
  function automatic string rf_detail(input string asm);
    return asm;
  endfunction

  task automatic log_preload_ref;
    tb_info_msg("Manual golden reference values for check_rf exp columns");
    tb_info_msg("GPR preload operands, committed per test by preload_gpr");
    tb_field_u32("PRE_x1", PRE_X1, PRE_X1);
    tb_field_u32("PRE_x2", PRE_X2, PRE_X2);
    tb_field_u32("PRE_x3", PRE_X3, PRE_X3);
    tb_field_u32("PRE_x5", PRE_X5, PRE_X5);
    tb_field_u32("PRE_x6", PRE_X6, PRE_X6);
    tb_field_u32("PRE_x7", PRE_X7, PRE_X7);
    tb_field_u32("PRE_x9", PRE_X9, PRE_X9);
    tb_info_msg("WB bus golden payloads and PC references");
    tb_info_msg("WB merge rule: same rd both lanes, youngest insn wins via higher wpc only");
    tb_info_msg("WB tests label WB even, WB odd, ID even, ID odd (mutually exclusive stages)");
    tb_field_u32("WB_X2_IMM",   WB_X2_IMM,   WB_X2_IMM);
    tb_field_u32("WB_X2_ADDI",  WB_X2_ADDI,  WB_X2_ADDI);
    tb_field_u32("WB_X2_LW",    WB_X2_LW,    WB_X2_LW);
    tb_info_msg("Green Card odd_wdata: jal/jalr R[rd]=insn_PC+4 only");
    tb_field_u32("ODD_PC",       ODD_PC,       ODD_PC);
    tb_field_u32("WB_JAL_LINK",  WB_JAL_LINK,  WB_JAL_LINK);
    tb_info_msg("Green Card odd_wdata: lui R[rd]=imm<<12, auipc R[rd]=insn_PC+(imm<<12)");
    tb_field_u32("LUI_IMM_2A",   LUI_IMM_2A,   LUI_IMM_2A);
    tb_field_u32("WB_LUI_X7",    WB_LUI_X7,    WB_LUI_X7);
    tb_field_u32("AUIPC_IMM_2",  AUIPC_IMM_2,  AUIPC_IMM_2);
    tb_field_u32("WB_AUIPC_X7",  WB_AUIPC_X7,  WB_AUIPC_X7);
    tb_info_msg("Mnemonic detail strings use 0x hex for imm/offset fields");
    tb_info_msg("Immediates for mnemonic detail strings");
    tb_field_u32("JAL_IMM_0",   JAL_IMM_0,   JAL_IMM_0);
    tb_field_u32("JALR_IMM_0",  JALR_IMM_0,  JALR_IMM_0);
    tb_field_u32("LOAD_IMM_0",  LOAD_IMM_0,  LOAD_IMM_0);
    tb_field_u32("STORE_IMM_0", STORE_IMM_0, STORE_IMM_0);
    tb_case_sep();
  endtask

  // Idle lane: addi x0,x0,0 (even), all read addrs and data zero
  localparam logic [6:0] IDLE_EVEN_OPC = OPC_OP_IMM;
  localparam logic [4:0] IDLE_EVEN_RS1 = ADDR_X0;
  localparam logic [4:0] IDLE_EVEN_RS2 = ADDR_X0;
  // Idle lane: lui x0,0 (odd), all read addrs and data zero
  localparam logic [6:0] IDLE_ODD_OPC  = OPC_LUI;
  localparam logic [4:0] IDLE_ODD_RS1  = ADDR_X0;
  localparam logic [4:0] IDLE_ODD_RS2  = ADDR_X0;

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
    log_preload_ref();

    // =========================================================================
    // Single instruction test cases, ID read only wen=0, idle lane all zero
    // =========================================================================
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd2, PRE_X2);
    set_reads_dec(OPC_OP, 5'd5, 5'd2, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even R-type",
      rf_detail("add x7,x5,x2, idle odd"),
      ADDR_X5, ADDR_X2, ADDR_X0, ADDR_X0,
      PRE_X5, PRE_X2, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_OP, 5'd5, 5'd6);
    check_rf("single odd R-type",
      rf_detail("idle even, sub x7,x5,x6"),
      ADDR_X0, ADDR_X0, ADDR_X5, ADDR_X6,
      32'd0, 32'd0, PRE_X5, PRE_X6,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_OP_IMM, 5'd5, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even I-type",
      rf_detail("ori x7,x5,0x2a, idle odd"),
      ADDR_X5, ADDR_X0, ADDR_X0, ADDR_X0,
      PRE_X5, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_OP_IMM, 5'd5, 5'd0);
    check_rf("single odd I-type",
      rf_detail("idle even, andi x7,x5,0x2b"),
      ADDR_X0, ADDR_X0, ADDR_X5, ADDR_X0,
      32'd0, 32'd0, PRE_X5, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd9, PRE_X9);
    set_reads_dec(OPC_BRANCH, 5'd7, 5'd9, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even B-type",
      rf_detail("beq x7, x9, 0x00, idle odd"),
      ADDR_X7, ADDR_X9, ADDR_X0, ADDR_X0,
      PRE_X7, PRE_X9, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_BRANCH, 5'd1, 5'd5);
    check_rf("single odd B-type",
      rf_detail("idle even, bne x1, x5, 0x00"),
      ADDR_X0, ADDR_X0, ADDR_X1, ADDR_X5,
      32'd0, 32'd0, PRE_X1, PRE_X5,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    set_reads_dec(OPC_JAL, 5'd0, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even J-type",
      rf_detail("jal x7, 0x00, idle odd"),
      ADDR_X0, ADDR_X0, ADDR_X0, ADDR_X0,
      32'd0, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_JALR, 5'd6, 5'd0);
    check_rf("single odd J-type",
      rf_detail("idle even, jalr x7, 0x00(x6)"),
      ADDR_X0, ADDR_X0, ADDR_X6, ADDR_X0,
      32'd0, 32'd0, PRE_X6, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_LOAD, 5'd5, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("single even load",
      rf_detail("lw x7, 0x00(x5), idle odd"),
      ADDR_X5, ADDR_X0, ADDR_X0, ADDR_X0,
      PRE_X5, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(IDLE_EVEN_OPC, IDLE_EVEN_RS1, IDLE_EVEN_RS2, OPC_STORE, 5'd7, 5'd6);
    check_rf("single odd store",
      rf_detail("sw x6, 0x00(x7), idle even, ID read only"),
      ADDR_X0, ADDR_X0, ADDR_X7, ADDR_X6,
      32'd0, 32'd0, PRE_X7, PRE_X6,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
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
      ADDR_X5, ADDR_X0, ADDR_X7, ADDR_X9,
      PRE_X5, 32'd0, PRE_X7, PRE_X9,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(OPC_OP, 5'd5, 5'd6, OPC_OP, 5'd5, 5'd6);
    check_rf("both R-type same reads",
      rf_detail("or x1,x5,x6, srl x6,x5,x6, no write back"),
      ADDR_X5, ADDR_X6, ADDR_X5, ADDR_X6,
      PRE_X5, PRE_X6, PRE_X5, PRE_X6,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd7, PRE_X7);
    preload_gpr(5'd9, PRE_X9);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_OP, 5'd7, 5'd9, OPC_LOAD, 5'd5, 5'd0);
    check_rf("ideal case different reads",
      rf_detail("sub x6,x7,x9, lw x1, 0x00(x5), no write back"),
      ADDR_X7, ADDR_X9, ADDR_X5, ADDR_X0,
      PRE_X7, PRE_X9, PRE_X5, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd9, PRE_X9);
    preload_gpr(5'd6, PRE_X6);
    set_reads_dec(OPC_STORE, 5'd9, 5'd6, OPC_OP_IMM, 5'd9, 5'd0);
    check_rf("ideal case same reads",
      rf_detail("sw x6, 0x00(x9), ori x1,x9,0x2d, no write back"),
      ADDR_X9, ADDR_X6, ADDR_X9, ADDR_X0,
      PRE_X9, PRE_X6, PRE_X9, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    preload_gpr(5'd6, PRE_X6);
    preload_gpr(5'd7, PRE_X7);
    set_reads_dec(OPC_BRANCH, 5'd1, 5'd5, OPC_BRANCH, 5'd6, 5'd7);
    check_rf("both B-type different reads",
      rf_detail("blt x1, x5, 0x00, bge x6, x7, 0x00"),
      ADDR_X1, ADDR_X5, ADDR_X6, ADDR_X7,
      PRE_X1, PRE_X5, PRE_X6, PRE_X7,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd5, PRE_X5);
    set_reads_dec(OPC_BRANCH, 5'd1, 5'd5, OPC_BRANCH, 5'd1, 5'd5);
    check_rf("both B-type same reads",
      rf_detail("beq x1, x5, 0x00, bne x1, x5, 0x00"),
      ADDR_X1, ADDR_X5, ADDR_X1, ADDR_X5,
      PRE_X1, PRE_X5, PRE_X1, PRE_X5,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    // =========================================================================
    // WB + ID same cycle: WB even/odd completing, ID even/odd operand reads
    // =========================================================================
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    drive_writes(1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, '0, '0);
    set_reads_dec(OPC_OP, 5'd2, 5'd1, OPC_LOAD, 5'd2, 5'd0);
    check_rf("WB addi x2 imm",
      rf_detail("WB even addi x2,x1,0xfa0a505f, WB odd idle, ID even add x3,x2,x1, ID odd lw x1,0x00(x2)"),
      ADDR_X2, ADDR_X1, ADDR_X2, ADDR_X0,
      WB_X2_IMM, PRE_X1, WB_X2_IMM, 32'd0,
      1'b1, ADDR_X2, WB_X2_IMM, EVEN_WPC_0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    preload_gpr(5'd3, PRE_X3);
    drive_writes(1'b1, 5'd2, WB_X2_IMM, EVEN_WPC_0, 1'b0, 5'd0, '0, '0);
    set_reads_dec(OPC_OP, 5'd2, 5'd3, OPC_LOAD, 5'd2, 5'd0);
    check_rf("WB add x2 reg",
      rf_detail("WB even add x2,x1,x3, WB odd idle, ID even add x4,x2,x3, ID odd lw x1,0x00(x2)"),
      ADDR_X2, ADDR_X3, ADDR_X2, ADDR_X0,
      WB_X2_IMM, PRE_X3, WB_X2_IMM, 32'd0,
      1'b1, ADDR_X2, WB_X2_IMM, EVEN_WPC_0, 1'b0, ADDR_X0, 32'd0, 32'd0);
    isolated_reset();
    preload_gpr(5'd1, PRE_X1);
    drive_writes(1'b1, 5'd2, WB_X2_ADDI, EVEN_WPC_0, 1'b1, 5'd2, WB_X2_LW, ODD_WPC_4);
    set_reads_dec(OPC_OP, 5'd2, 5'd1, OPC_LOAD, 5'd2, 5'd0);
    check_rf("WB merge same rd youngest wins",
      rf_detail("WB even addi x2,x1,0xaa, WB odd lw x2,0x00(x2), ID even add x3,x2,x1, ID odd lw x1,0x00(x2)"),
      ADDR_X2, ADDR_X1, ADDR_X2, ADDR_X0,
      WB_X2_LW, PRE_X1, WB_X2_LW, 32'd0,
      1'b1, ADDR_X2, WB_X2_ADDI, EVEN_WPC_0,
      1'b1, ADDR_X2, WB_X2_LW, ODD_WPC_4);
    // =========================================================================
    // Odd-lane WB specials (wpc = ODD_PC). Green Card GPR results only:
    //   jal/jalr: R[rd] = PC+4  -> odd_wdata = ODD_PC+4 (0x1008), not jump target
    //   lui:      R[rd] = imm<<12
    //   auipc:    R[rd] = PC+(imm<<12) using insn PC = ODD_PC
    // =========================================================================
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    set_reads_dec(OPC_LOAD, 5'd7, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB jal odd",
      rf_detail("WB even idle, WB odd jal x7,0x00, ID even lw x1,0x00(x7), ID odd idle"),
      ADDR_X7, ADDR_X0, ADDR_X0, ADDR_X0,
      WB_JAL_LINK, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b1, ADDR_X7, WB_JAL_LINK, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_JAL_LINK, ODD_PC);
    set_reads_dec(OPC_LOAD, 5'd7, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB jalr odd",
      rf_detail("WB even idle, WB odd jalr x7,0x00(x6), ID even lw x1,0x00(x7), ID odd idle"),
      ADDR_X7, ADDR_X0, ADDR_X0, ADDR_X0,
      WB_JAL_LINK, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b1, ADDR_X7, WB_JAL_LINK, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_LUI_X7, ODD_PC);
    set_reads_dec(OPC_LOAD, 5'd7, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB lui odd",
      rf_detail("WB even idle, WB odd lui x7,0x2a, ID even lw x1,0x00(x7), ID odd idle"),
      ADDR_X7, ADDR_X0, ADDR_X0, ADDR_X0,
      WB_LUI_X7, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b1, ADDR_X7, WB_LUI_X7, ODD_PC);
    isolated_reset();
    drive_writes(1'b0, 5'd0, '0, '0, 1'b1, 5'd7, WB_AUIPC_X7, ODD_PC);
    set_reads_dec(OPC_LOAD, 5'd7, 5'd0, IDLE_ODD_OPC, IDLE_ODD_RS1, IDLE_ODD_RS2);
    check_rf("WB auipc odd",
      rf_detail("WB even idle, WB odd auipc x7,0x02, ID even lw x1,0x00(x7), ID odd idle"),
      ADDR_X7, ADDR_X0, ADDR_X0, ADDR_X0,
      WB_AUIPC_X7, 32'd0, 32'd0, 32'd0,
      1'b0, ADDR_X0, 32'd0, 32'd0, 1'b1, ADDR_X7, WB_AUIPC_X7, ODD_PC);
    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "register_file_tb failed");
    $finish;
  end

endmodule