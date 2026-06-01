`timescale 1ns / 1ps

// Unit testbench for decoder (RV32I field decode, imm, lane_sel, GPR uses, legality).
module decoder_tb;

  import rv_dis_pkg::*;
  import rv_dis_decode_pkg::*;

  `include "common/tb_console.svh"

  logic        valid_in;
  logic [31:0] instr;
  logic [31:0] pc;

  logic        valid_out;
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

  decoder dut (.*);

  task automatic run_insn;
    input logic [31:0] insn_i;
    input logic [31:0] pc_i;
    valid_in = 1'b1;
    instr    = insn_i;
    pc       = pc_i;
    #1;
  endtask

  task automatic check(
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
    input logic [31:0] exp_pc,
    input logic        exp_rs1_use,
    input logic        exp_rs2_use,
    input logic        exp_reg_write
  );
    string got;
    if (valid_out !== exp_valid || lane_sel !== exp_lane ||
        opcode !== exp_opcode || funct3 !== exp_funct3 || funct7 !== exp_funct7 ||
        rd !== exp_rd || rs1 !== exp_rs1 || rs2 !== exp_rs2 ||
        imm !== exp_imm || pc_out !== exp_pc ||
        rs1_use !== exp_rs1_use || rs2_use !== exp_rs2_use ||
        reg_write !== exp_reg_write) begin
      got = $sformatf("%s | v=%0d lane=%0d op=%07b f3=%0d f7=%02h rd=%0d rs1=%0d rs2=%0d imm=%h pc=%h",
        detail, valid_out, lane_sel, opcode, funct3, funct7, rd, rs1, rs2, imm, pc_out);
      tb_fail_detail(name, got);
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  // insn present (valid_in=1) but not in RV32I subset → valid_out=0
  task automatic check_reject(
    input string name,
    input string detail
  );
    if (valid_in !== 1'b1 || valid_out !== 1'b0) begin
      tb_fail_detail(name, $sformatf("%s | expected valid_in=1 valid_out=0, got in=%0d out=%0d",
        detail, valid_in, valid_out));
      fail_cnt++;
    end else begin
      tb_pass_detail(name, detail);
      pass_cnt++;
    end
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("decoder_tb - RV32I decode / lane_sel / imm");
    tb_info_msg("Reject insn: valid_in && !valid_out");

    run_insn(32'h0043_0313, 32'h0000_1000);
    check("addi", "ADDI x5,x6,+4", 1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'b0,
      5'd5, 5'd6, 5'd0, 32'd4, 32'h0000_1000, 1'b1, 1'b0, 1'b1);

    run_insn(32'h0052_0233, 32'h0000_1004);
    check("add", "ADD x3,x4,x5", 1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'b0,
      5'd3, 5'd4, 5'd5, 32'd0, 32'h0000_1004, 1'b1, 1'b1, 1'b1);

    run_insn(32'h4052_0233, 32'h0000_1008);
    check("sub", "SUB x3,x4,x5", 1, LANE_EVEN, OPC_OP, F3_ADD_SUB, F7_SUB,
      5'd3, 5'd4, 5'd5, 32'd0, 32'h0000_1008, 1'b1, 1'b1, 1'b1);

    run_insn(32'h0085_2383, 32'h0000_2000);
    check("lw", "LW x7,8(x10)", 1, LANE_ODD, OPC_LOAD, F3_LW, 7'b0,
      5'd7, 5'd10, 5'd0, 32'd8, 32'h0000_2000, 1'b1, 1'b0, 1'b1);

    run_insn(32'h0063_8C23, 32'h0000_2004);
    check("sw", "SW x6,4(x7)", 1, LANE_ODD, OPC_STORE, F3_SW, 7'b0,
      5'd0, 5'd7, 5'd6, 32'd4, 32'h0000_2004, 1'b1, 1'b1, 1'b0);

    run_insn(32'h0100_0A63, 32'h0000_3000);
    check("beq", "BEQ x1,x2,+16", 1, LANE_ODD, OPC_BRANCH, F3_BEQ, 7'b0,
      5'd0, 5'd1, 5'd2, 32'd16, 32'h0000_3000, 1'b1, 1'b1, 1'b0);

    run_insn(32'h0080_006F, 32'h0000_4000);
    check("jal", "JAL x1,+8", 1, LANE_ODD, OPC_JAL, 3'b0, 7'b0,
      5'd1, 5'd0, 5'd0, 32'd8, 32'h0000_4000, 1'b0, 1'b0, 1'b1);

    run_insn(32'h0001_8197, 32'h0000_4004);
    check("jalr", "JALR x2,0(x3)", 1, LANE_ODD, OPC_JALR, 3'b0, 7'b0,
      5'd2, 5'd3, 5'd0, 32'd0, 32'h0000_4004, 1'b1, 1'b0, 1'b1);

    run_insn(32'h1234_5437, 32'h0000_5000);
    check("lui", "LUI x8,0x12345", 1, LANE_ODD, OPC_LUI, 3'b0, 7'b0,
      5'd8, 5'd0, 5'd0, 32'h1234_5000, 32'h0000_5000, 1'b0, 1'b0, 1'b1);

    run_insn(32'h0000_0497, 32'h0000_5004);
    check("auipc", "AUIPC x9,0x1", 1, LANE_ODD, OPC_AUIPC, 3'b0, 7'b0,
      5'd9, 5'd0, 5'd0, 32'h0000_1000, 32'h0000_5004, 1'b0, 1'b0, 1'b1);

    run_insn(32'h0010_0013, 32'h0000_6000);
    check("addi_x0", "ADDI x0,x1,1 no reg_write", 1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'b0,
      5'd0, 5'd1, 5'd0, 32'd1, 32'h0000_6000, 1'b1, 1'b0, 1'b0);

    run_insn(32'h0000_2383, 32'h0000_7000);
    instr[14:12] = 3'b000;
    #1;
    check_reject("lb", "LB not in subset");

    run_insn(32'h0000_0023, 32'h0000_7004);
    instr[6:0]  = OPC_STORE;
    instr[14:12] = 3'b001;
    #1;
    check_reject("sh", "SH not in subset");

    run_insn(32'hFFFF_FFFF, 32'h0000_8000);
    check_reject("bad_opcode", "unknown opcode");

    valid_in = 1'b0;
    instr    = 32'h0043_0313;
    pc       = 32'h0000_9000;
    #1;
    check("valid0", "valid_in=0 bubble", 0, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'b0,
      5'd5, 5'd6, 5'd0, 32'd4, 32'h0000_9000, 1'b1, 1'b0, 1'b0);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "decoder_tb failed");
    $finish;
  end

endmodule
