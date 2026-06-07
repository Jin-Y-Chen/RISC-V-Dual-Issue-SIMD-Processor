`timescale 1ns / 1ps

// decoder_tb — DUT vs hand-written expected decode (no decode_pkg; independent of RTL decode helpers).
module decoder_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  logic [31:0] instr;
  logic [31:0] pc;

  logic        valid;
  lane_sel_e   lane_sel;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [4:0]  rd;
  logic [4:0]  rs1;
  logic [4:0]  rs2;
  logic [31:0] imm;
  logic [31:0] pc_out;
  logic        rs1_use;
  logic        rs2_use;
  logic        reg_write;

  int pass_cnt;
  int fail_cnt;

  decoder dut (
    .instr      (instr),
    .pc         (pc),
    .valid      (valid),
    .lane_sel   (lane_sel),
    .opcode     (opcode),
    .funct3     (funct3),
    .funct7     (funct7),
    .rd         (rd),
    .rs1        (rs1),
    .rs2        (rs2),
    .imm        (imm),
    .pc_out     (pc_out),
    .rs1_use    (rs1_use),
    .rs2_use    (rs2_use),
    .reg_write  (reg_write)
  );

  task automatic run_insn;
    input logic [31:0] insn_i;
    input logic [31:0] pc_i;
    instr    = insn_i;
    pc       = pc_i;
    #1;
  endtask

  // Compare DUT outputs to caller-supplied expected values (independent golden).
  task automatic check_expect(
    input string       name,
    input string       detail,
    input logic        exp_valid,
    input lane_sel_e   exp_lane,
    input logic [6:0]  exp_opcode,
    input logic [2:0]  exp_funct3,
    input logic [6:0]  exp_funct7,
    input logic [4:0]  exp_rd,
    input logic [4:0]  exp_rs1,
    input logic [4:0]  exp_rs2,
    input logic [31:0] exp_imm,
    input logic        exp_rs1_use,
    input logic        exp_rs2_use,
    input logic        exp_reg_write
  );
    bit pass;
    pass = (valid === exp_valid && lane_sel === exp_lane &&
            opcode === exp_opcode && funct3 === exp_funct3 && funct7 === exp_funct7 &&
            rd === exp_rd && rs1 === exp_rs1 && rs2 === exp_rs2 &&
            imm === exp_imm && pc_out === pc &&
            rs1_use === exp_rs1_use && rs2_use === exp_rs2_use &&
            reg_write === exp_reg_write);
    tb_report_open(pass, name, detail);
    tb_field_bit("valid", valid, exp_valid);
    tb_field_lane("lane_sel", lane_sel, exp_lane);
    tb_field_op7("opcode", opcode, exp_opcode);
    tb_field_f3("funct3", funct3, exp_funct3);
    tb_field_f7("funct7", funct7, exp_funct7);
    tb_field_u5("rd", rd, exp_rd);
    tb_field_u5("rs1", rs1, exp_rs1);
    tb_field_u5("rs2", rs2, exp_rs2);
    tb_field_u32("imm", imm, exp_imm);
    tb_field_u32("pc_out", pc_out, pc);
    tb_field_bit("rs1_use", rs1_use, exp_rs1_use);
    tb_field_bit("rs2_use", rs2_use, exp_rs2_use);
    tb_field_bit("reg_write", reg_write, exp_reg_write);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_reject(input string name, input string detail);
    bit pass;
    pass = (valid === 1'b0);
    tb_report_open(pass, name, detail);
    tb_field_bit("valid", valid, 1'b0);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_bubble(input string name, input logic [31:0] insn_i, input logic [31:0] pc_i);
    bit pass;
    instr = insn_i;
    pc    = pc_i;
    #1;
    pass = (valid === 1'b0);
    tb_report_open(pass, name, "flush bubble illegal insn");
    tb_field_bit("valid", valid, 1'b0);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("decoder_tb - hand-written expected decode");
    tb_info_msg("Golden values are explicit per test (not decode_pkg)");

    // --- Even lane: OP-IMM (varied rd/rs1 per test) ---
    run_insn(32'h0046_8613, 32'h0000_1000);
    check_expect("addi", "ADDI x12,x13,+4", 1'b1, LANE_EVEN,
      7'b0010011, 3'b000, 7'h00, 5'd12, 5'd13, 5'd0, 32'd4,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h0027_9713, 32'h0000_1004);
    check_expect("slli", "SLLI x14,x15,2", 1'b1, LANE_EVEN,
      7'b0010011, 3'b001, 7'h00, 5'd14, 5'd15, 5'd0, 32'd2,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h0018_D813, 32'h0000_1008);
    check_expect("srli", "SRLI x16,x17,1", 1'b1, LANE_EVEN,
      7'b0010011, 3'b101, 7'h00, 5'd16, 5'd17, 5'd0, 32'd1,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h4039_D913, 32'h0000_100C);
    check_expect("srai", "SRAI x18,x19,3", 1'b1, LANE_EVEN,
      7'b0010011, 3'b101, 7'h20, 5'd18, 5'd19, 5'd0, 32'h0000_0403,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h00AA_AA13, 32'h0000_1010);
    check_expect("slti", "SLTI x20,x21,10", 1'b1, LANE_EVEN,
      7'b0010011, 3'b010, 7'h00, 5'd20, 5'd21, 5'd0, 32'd10,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h0FFB_CB13, 32'h0000_1014);
    check_expect("xori", "XORI x22,x23,0xFF", 1'b1, LANE_EVEN,
      7'b0010011, 3'b100, 7'h00, 5'd22, 5'd23, 5'd0, 32'd255,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h00FC_EC13, 32'h0000_1018);
    check_expect("ori", "ORI x24,x25,15", 1'b1, LANE_EVEN,
      7'b0010011, 3'b110, 7'h00, 5'd24, 5'd25, 5'd0, 32'd15,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h00FD_FD13, 32'h0000_101C);
    check_expect("andi", "ANDI x26,x27,15", 1'b1, LANE_EVEN,
      7'b0010011, 3'b111, 7'h00, 5'd26, 5'd27, 5'd0, 32'd15,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h001E_0013, 32'h0000_1020);
    check_expect("addi_x0", "ADDI x0,x28,1", 1'b1, LANE_EVEN,
      7'b0010011, 3'b000, 7'h00, 5'd0, 5'd28, 5'd0, 32'd1,
      1'b1, 1'b0, 1'b0);

    // --- Even lane: OP (R-type) ---
    run_insn(32'h0094_03B3, 32'h0000_1100);
    check_expect("add", "ADD x7,x8,x9", 1'b1, LANE_EVEN,
      7'b0110011, 3'b000, 7'h00, 5'd7, 5'd8, 5'd9, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h40C5_8533, 32'h0000_1104);
    check_expect("sub", "SUB x10,x11,x12", 1'b1, LANE_EVEN,
      7'b0110011, 3'b000, 7'h20, 5'd10, 5'd11, 5'd12, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h00F7_16B3, 32'h0000_1108);
    check_expect("sll", "SLL x13,x14,x15", 1'b1, LANE_EVEN,
      7'b0110011, 3'b001, 7'h00, 5'd13, 5'd14, 5'd15, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h0128_A833, 32'h0000_110C);
    check_expect("slt", "SLT x16,x17,x18", 1'b1, LANE_EVEN,
      7'b0110011, 3'b010, 7'h00, 5'd16, 5'd17, 5'd18, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h015A_49B3, 32'h0000_1110);
    check_expect("xor", "XOR x19,x20,x21", 1'b1, LANE_EVEN,
      7'b0110011, 3'b100, 7'h00, 5'd19, 5'd20, 5'd21, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h018B_DB33, 32'h0000_1114);
    check_expect("srl", "SRL x22,x23,x24", 1'b1, LANE_EVEN,
      7'b0110011, 3'b101, 7'h00, 5'd22, 5'd23, 5'd24, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h41BD_5CB3, 32'h0000_1118);
    check_expect("sra", "SRA x25,x26,x27", 1'b1, LANE_EVEN,
      7'b0110011, 3'b101, 7'h20, 5'd25, 5'd26, 5'd27, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h01EE_EE33, 32'h0000_111C);
    check_expect("or", "OR x28,x29,x30", 1'b1, LANE_EVEN,
      7'b0110011, 3'b110, 7'h00, 5'd28, 5'd29, 5'd30, 32'd0,
      1'b1, 1'b1, 1'b1);

    run_insn(32'h0062_FFB3, 32'h0000_1120);
    check_expect("and", "AND x31,x5,x6", 1'b1, LANE_EVEN,
      7'b0110011, 3'b111, 7'h00, 5'd31, 5'd5, 5'd6, 32'd0,
      1'b1, 1'b1, 1'b1);

    // --- Odd lane: load/store ---
    run_insn(32'h0086_2583, 32'h0000_2000);
    check_expect("lw", "LW x11,8(x12)", 1'b1, LANE_ODD,
      7'b0000011, 3'b010, 7'h00, 5'd11, 5'd12, 5'd0, 32'd8,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h00D7_2223, 32'h0000_2004);
    check_expect("sw", "SW x13,4(x14)", 1'b1, LANE_ODD,
      7'b0100011, 3'b010, 7'h00, 5'd0, 5'd14, 5'd13, 32'd4,
      1'b1, 1'b1, 1'b0);

    // --- Odd lane: branches (offset +16 bytes) ---
    run_insn(32'h0107_8863, 32'h0000_3000);
    check_expect("beq", "BEQ x15,x16,+16", 1'b1, LANE_ODD,
      7'b1100011, 3'b000, 7'h00, 5'd0, 5'd15, 5'd16, 32'd16,
      1'b1, 1'b1, 1'b0);

    run_insn(32'h0128_9863, 32'h0000_3004);
    check_expect("bne", "BNE x17,x18,+16", 1'b1, LANE_ODD,
      7'b1100011, 3'b001, 7'h00, 5'd0, 5'd17, 5'd18, 32'd16,
      1'b1, 1'b1, 1'b0);

    run_insn(32'h0149_C863, 32'h0000_3008);
    check_expect("blt", "BLT x19,x20,+16", 1'b1, LANE_ODD,
      7'b1100011, 3'b100, 7'h00, 5'd0, 5'd19, 5'd20, 32'd16,
      1'b1, 1'b1, 1'b0);

    run_insn(32'h016A_D863, 32'h0000_300C);
    check_expect("bge", "BGE x21,x22,+16", 1'b1, LANE_ODD,
      7'b1100011, 3'b101, 7'h00, 5'd0, 5'd21, 5'd22, 32'd16,
      1'b1, 1'b1, 1'b0);

    // --- Odd lane: jumps / upper immediate ---
    run_insn(32'h0080_0BEF, 32'h0000_4000);
    check_expect("jal", "JAL x23,+8", 1'b1, LANE_ODD,
      7'b1101111, 3'b000, 7'h00, 5'd23, 5'd0, 5'd0, 32'd8,
      1'b0, 1'b0, 1'b1);

    run_insn(32'h000C_8C67, 32'h0000_4004);
    check_expect("jalr", "JALR x24,0(x25)", 1'b1, LANE_ODD,
      7'b1100111, 3'b000, 7'h00, 5'd24, 5'd25, 5'd0, 32'd0,
      1'b1, 1'b0, 1'b1);

    run_insn(32'h1234_5D37, 32'h0000_5000);
    check_expect("lui", "LUI x26,0x12345", 1'b1, LANE_ODD,
      7'b0110111, 3'b000, 7'h00, 5'd26, 5'd0, 5'd0, 32'h1234_5000,
      1'b0, 1'b0, 1'b1);

    run_insn(32'h0000_1D97, 32'h0000_5004);
    check_expect("auipc", "AUIPC x27,1", 1'b1, LANE_ODD,
      7'b0010111, 3'b000, 7'h00, 5'd27, 5'd0, 5'd0, 32'h0000_1000,
      1'b0, 1'b0, 1'b1);

    // --- Illegal in RV-DIS subset ---
    run_insn(32'h0086_2583, 32'h0000_7000);  // lw → patch funct3 to LB (000)
    instr[14:12] = 3'b000;
    #1;
    check_reject("lb", "LB funct3");

    run_insn(32'h0000_0023, 32'h0000_7004);
    instr[6:0]   = 7'b0100011;  // STORE
    instr[14:12] = 3'b001;      // SH
    #1;
    check_reject("sh", "SH funct3");

    run_insn(32'hFFFF_FFFF, 32'h0000_8000);
    check_reject("bad_opcode", "unknown opcode");

    check_bubble("flush_zero", 32'h0000_0000, 32'h0000_9000);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "decoder_tb failed");
    $finish;
  end

endmodule
