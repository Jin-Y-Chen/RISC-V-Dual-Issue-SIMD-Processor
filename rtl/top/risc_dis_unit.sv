`timescale 1ns / 1ps

// RV-DIS scalar core slice: ID through EX/MEM (no fetch, no MEM/WB yet).
// Dual decoders + GPR + ID/EX dispatch + forward unit + four lane copies
// (ev0/ev1, od0/od1) each with a dedicated EX/MEM register.
module risc_dis_unit
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // Decode inputs (instr + pc per slot; fetch / IF/ID live outside this block)
  input  logic [31:0] i0_instr_id,
  input  logic [31:0] i1_instr_id,
  input  logic [31:0] i0_pc_id,
  input  logic [31:0] i1_pc_id,

  // I1 replay request when I0->I1 RAW cannot same-cycle forward (e.g. LW)
  output logic        i1_stall
);

  // -------------------------------------------------------------------------
  // Decoder — one instance per slot (I0 older, I1 younger)
  // -------------------------------------------------------------------------
  logic        i0_valid_dec;
  lane_sel_e   i0_lane_sel_dec;
  logic [6:0]  i0_opcode_dec;
  logic [2:0]  i0_funct3_dec;
  logic [6:0]  i0_funct7_dec;
  logic [4:0]  i0_rd_dec;
  logic [4:0]  i0_rs1_dec;
  logic [4:0]  i0_rs2_dec;
  logic [31:0] i0_imm_dec;
  logic        i0_rs1_use_dec;
  logic        i0_rs2_use_dec;
  logic        i0_reg_write_dec;

  logic        i1_valid_dec;
  lane_sel_e   i1_lane_sel_dec;
  logic [6:0]  i1_opcode_dec;
  logic [2:0]  i1_funct3_dec;
  logic [6:0]  i1_funct7_dec;
  logic [4:0]  i1_rd_dec;
  logic [4:0]  i1_rs1_dec;
  logic [4:0]  i1_rs2_dec;
  logic [31:0] i1_imm_dec;
  logic        i1_rs1_use_dec;
  logic        i1_rs2_use_dec;
  logic        i1_reg_write_dec;

  decoder u_dec_i0 (
    .instr     (i0_instr_id),
    .valid     (i0_valid_dec),
    .lane_sel  (i0_lane_sel_dec),
    .opcode    (i0_opcode_dec),
    .funct3    (i0_funct3_dec),
    .funct7    (i0_funct7_dec),
    .rd        (i0_rd_dec),
    .rs1       (i0_rs1_dec),
    .rs2       (i0_rs2_dec),
    .imm       (i0_imm_dec),
    .rs1_use   (i0_rs1_use_dec),
    .rs2_use   (i0_rs2_use_dec),
    .reg_write (i0_reg_write_dec)
  );

  decoder u_dec_i1 (
    .instr     (i1_instr_id),
    .valid     (i1_valid_dec),
    .lane_sel  (i1_lane_sel_dec),
    .opcode    (i1_opcode_dec),
    .funct3    (i1_funct3_dec),
    .funct7    (i1_funct7_dec),
    .rd        (i1_rd_dec),
    .rs1       (i1_rs1_dec),
    .rs2       (i1_rs2_dec),
    .imm       (i1_imm_dec),
    .rs1_use   (i1_rs1_use_dec),
    .rs2_use   (i1_rs2_use_dec),
    .reg_write (i1_reg_write_dec)
  );

  // -------------------------------------------------------------------------
  // Register file — slot-named read ports; WB tied off until mem_wb is added
  // -------------------------------------------------------------------------
  reg_t i0_rs1_data;
  reg_t i0_rs2_data;
  reg_t i1_rs1_data;
  reg_t i1_rs2_data;

  register_file u_regfile (
    .clk         (clk),
    .rst_n       (rst_n),
    .i0_rs1_use  (i0_rs1_use_dec),
    .i0_rs2_use  (i0_rs2_use_dec),
    .i0_rs1_addr (i0_rs1_dec),
    .i0_rs2_addr (i0_rs2_dec),
    .i0_rs1_data (i0_rs1_data),
    .i0_rs2_data (i0_rs2_data),
    .i1_rs1_use  (i1_rs1_use_dec),
    .i1_rs2_use  (i1_rs2_use_dec),
    .i1_rs1_addr (i1_rs1_dec),
    .i1_rs2_addr (i1_rs2_dec),
    .i1_rs1_data (i1_rs1_data),
    .i1_rs2_data (i1_rs2_data),
    .i0_wen      (1'b0),
    .i0_rd       (5'd0),
    .i0_wdata    ('0),
    .i0_wpc      ('0),
    .i1_wen      (1'b0),
    .i1_rd       (5'd0),
    .i1_wdata    ('0),
    .i1_wpc      ('0)
  );

  // -------------------------------------------------------------------------
  // ID/EX dispatch — fixed slot map into four lane copies
  // -------------------------------------------------------------------------
  logic        i0_reg_write_ex;
  logic        i1_reg_write_ex;
  logic [31:0] i0_pc_ex;
  logic [31:0] i1_pc_ex;

  logic        ev0_enable_ex;
  logic [6:0]  ev0_opcode_ex;
  logic [2:0]  ev0_funct3_ex;
  logic [6:0]  ev0_funct7_ex;
  logic [4:0]  ev0_rd_ex;
  logic [4:0]  ev0_rs1_addr_ex;
  logic [4:0]  ev0_rs2_addr_ex;
  logic [31:0] ev0_imm_ex;
  logic [31:0] ev0_rs1_data_ex;
  logic [31:0] ev0_rs2_data_ex;
  logic [31:0] ev0_pc_ex;

  logic        ev1_enable_ex;
  logic [6:0]  ev1_opcode_ex;
  logic [2:0]  ev1_funct3_ex;
  logic [6:0]  ev1_funct7_ex;
  logic [4:0]  ev1_rd_ex;
  logic [4:0]  ev1_rs1_addr_ex;
  logic [4:0]  ev1_rs2_addr_ex;
  logic [31:0] ev1_imm_ex;
  logic [31:0] ev1_rs1_data_ex;
  logic [31:0] ev1_rs2_data_ex;
  logic [31:0] ev1_pc_ex;

  logic        od0_enable_ex;
  logic [6:0]  od0_opcode_ex;
  logic [2:0]  od0_funct3_ex;
  logic [4:0]  od0_rd_ex;
  logic [4:0]  od0_rs1_addr_ex;
  logic [4:0]  od0_rs2_addr_ex;
  logic [31:0] od0_imm_ex;
  logic [31:0] od0_rs1_data_ex;
  logic [31:0] od0_rs2_data_ex;
  logic [31:0] od0_pc_ex;

  logic        od1_enable_ex;
  logic [6:0]  od1_opcode_ex;
  logic [2:0]  od1_funct3_ex;
  logic [4:0]  od1_rd_ex;
  logic [4:0]  od1_rs1_addr_ex;
  logic [4:0]  od1_rs2_addr_ex;
  logic [31:0] od1_imm_ex;
  logic [31:0] od1_rs1_data_ex;
  logic [31:0] od1_rs2_data_ex;
  logic [31:0] od1_pc_ex;

  id_ex_dispatch u_dispatch (
    .clk             (clk),
    .rst_n           (rst_n),
    .flush           (flush),
    .i0_valid_id     (i0_valid_dec),
    .i0_lane_sel_id  (i0_lane_sel_dec),
    .i0_opcode_id    (i0_opcode_dec),
    .i0_funct3_id    (i0_funct3_dec),
    .i0_funct7_id    (i0_funct7_dec),
    .i0_rd_addr_id   (i0_rd_dec),
    .i0_rs1_addr_id  (i0_rs1_dec),
    .i0_rs2_addr_id  (i0_rs2_dec),
    .i0_reg_write_id (i0_reg_write_dec),
    .i0_imm_id       (i0_imm_dec),
    .i0_rs1_data_id  (i0_rs1_data),
    .i0_rs2_data_id  (i0_rs2_data),
    .i0_pc_id        (i0_pc_id),
    .i1_valid_id     (i1_valid_dec),
    .i1_lane_sel_id  (i1_lane_sel_dec),
    .i1_opcode_id    (i1_opcode_dec),
    .i1_funct3_id    (i1_funct3_dec),
    .i1_funct7_id    (i1_funct7_dec),
    .i1_rd_addr_id   (i1_rd_dec),
    .i1_rs1_addr_id  (i1_rs1_dec),
    .i1_rs2_addr_id  (i1_rs2_dec),
    .i1_reg_write_id (i1_reg_write_dec),
    .i1_imm_id       (i1_imm_dec),
    .i1_rs1_data_id  (i1_rs1_data),
    .i1_rs2_data_id  (i1_rs2_data),
    .i1_pc_id        (i1_pc_id),
    .i0_reg_write_ex (i0_reg_write_ex),
    .i1_reg_write_ex (i1_reg_write_ex),
    .i0_pc_ex        (i0_pc_ex),
    .i1_pc_ex        (i1_pc_ex),
    .ev0_enable_ex   (ev0_enable_ex),
    .ev0_opcode_ex   (ev0_opcode_ex),
    .ev0_funct3_ex   (ev0_funct3_ex),
    .ev0_funct7_ex   (ev0_funct7_ex),
    .ev0_rd_ex       (ev0_rd_ex),
    .ev0_rs1_addr_ex (ev0_rs1_addr_ex),
    .ev0_rs2_addr_ex (ev0_rs2_addr_ex),
    .ev0_imm_ex      (ev0_imm_ex),
    .ev0_rs1_data_ex (ev0_rs1_data_ex),
    .ev0_rs2_data_ex (ev0_rs2_data_ex),
    .ev0_pc_ex       (ev0_pc_ex),
    .ev1_enable_ex   (ev1_enable_ex),
    .ev1_opcode_ex   (ev1_opcode_ex),
    .ev1_funct3_ex   (ev1_funct3_ex),
    .ev1_funct7_ex   (ev1_funct7_ex),
    .ev1_rd_ex       (ev1_rd_ex),
    .ev1_rs1_addr_ex (ev1_rs1_addr_ex),
    .ev1_rs2_addr_ex (ev1_rs2_addr_ex),
    .ev1_imm_ex      (ev1_imm_ex),
    .ev1_rs1_data_ex (ev1_rs1_data_ex),
    .ev1_rs2_data_ex (ev1_rs2_data_ex),
    .ev1_pc_ex       (ev1_pc_ex),
    .od0_enable_ex   (od0_enable_ex),
    .od0_opcode_ex   (od0_opcode_ex),
    .od0_funct3_ex   (od0_funct3_ex),
    .od0_rd_ex       (od0_rd_ex),
    .od0_rs1_addr_ex (od0_rs1_addr_ex),
    .od0_rs2_addr_ex (od0_rs2_addr_ex),
    .od0_imm_ex      (od0_imm_ex),
    .od0_rs1_data_ex (od0_rs1_data_ex),
    .od0_rs2_data_ex (od0_rs2_data_ex),
    .od0_pc_ex       (od0_pc_ex),
    .od1_enable_ex   (od1_enable_ex),
    .od1_opcode_ex   (od1_opcode_ex),
    .od1_funct3_ex   (od1_funct3_ex),
    .od1_rd_ex       (od1_rd_ex),
    .od1_rs1_addr_ex (od1_rs1_addr_ex),
    .od1_rs2_addr_ex (od1_rs2_addr_ex),
    .od1_imm_ex      (od1_imm_ex),
    .od1_rs1_data_ex (od1_rs1_data_ex),
    .od1_rs2_data_ex (od1_rs2_data_ex),
    .od1_pc_ex       (od1_pc_ex)
  );

  // -------------------------------------------------------------------------
  // Execution lanes (combinational) — wired after forward_unit below
  // -------------------------------------------------------------------------
  logic [31:0] ev0_alu_result;
  logic [31:0] ev1_alu_result;

  logic        od0_unit_done;
  logic        od0_brch_taken;
  logic [31:0] od0_brch_pc;
  logic        od0_mem_en;
  logic        od0_mem_act;
  logic [31:0] od0_mem_addr;
  logic [31:0] od0_mem_wdata;
  logic [3:0]  od0_mem_besel;
  logic [31:0] od0_link_pc;
  logic [31:0] od0_alu_result;

  logic        od1_brch_taken;
  logic [31:0] od1_brch_pc;
  logic        od1_mem_en;
  logic        od1_mem_act;
  logic [31:0] od1_mem_addr;
  logic [31:0] od1_mem_wdata;
  logic [3:0]  od1_mem_besel;
  logic [31:0] od1_link_pc;
  logic [31:0] od1_alu_result;

  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;

  // I0 odd-lane producer result for same-cycle forward (link_pc vs alu_result)
  logic [31:0] od0_result_fwd;
  assign od0_result_fwd = ((od0_opcode_ex == OPC_JAL) || (od0_opcode_ex == OPC_JALR))
                          ? od0_link_pc : od0_alu_result;

  // -------------------------------------------------------------------------
  // Forward unit — WB ports tied off until mem_wb is integrated
  // -------------------------------------------------------------------------
  forward_unit u_forward (
    .clk              (clk),
    .rst_n            (rst_n),
    .ev0_enable       (ev0_enable_ex),
    .ev0_rs1_addr     (ev0_rs1_addr_ex),
    .ev0_rs2_addr     (ev0_rs2_addr_ex),
    .ev0_rs1_data     (ev0_rs1_data_ex),
    .ev0_rs2_data     (ev0_rs2_data_ex),
    .ev1_enable       (ev1_enable_ex),
    .ev1_rs1_addr     (ev1_rs1_addr_ex),
    .ev1_rs2_addr     (ev1_rs2_addr_ex),
    .ev1_rs1_data     (ev1_rs1_data_ex),
    .ev1_rs2_data     (ev1_rs2_data_ex),
    .od0_enable       (od0_enable_ex),
    .od0_rs1_addr     (od0_rs1_addr_ex),
    .od0_rs2_addr     (od0_rs2_addr_ex),
    .od0_rs1_data     (od0_rs1_data_ex),
    .od0_rs2_data     (od0_rs2_data_ex),
    .od1_enable       (od1_enable_ex),
    .od1_rs1_addr     (od1_rs1_addr_ex),
    .od1_rs2_addr     (od1_rs2_addr_ex),
    .od1_rs1_data     (od1_rs1_data_ex),
    .od1_rs2_data     (od1_rs2_data_ex),
    .i0_reg_write     (i0_reg_write_ex),
    .i0_rd_addr       (ev0_rd_ex),
    .ev0_unit_done    (ev0_enable_ex),
    .ev0_result       (ev0_alu_result),
    .od0_unit_done    (od0_unit_done),
    .od0_result       (od0_result_fwd),
    .wb0_reg_write    (1'b0),
    .wb0_rd_addr      (5'd0),
    .wb0_data         ('0),
    .wb0_pc           ('0),
    .wb1_reg_write    (1'b0),
    .wb1_rd_addr      (5'd0),
    .wb1_data         ('0),
    .wb1_pc           ('0),
    .ev0_rs1_data_fwd (ev0_rs1_data_fwd),
    .ev0_rs2_data_fwd (ev0_rs2_data_fwd),
    .ev1_rs1_data_fwd (ev1_rs1_data_fwd),
    .ev1_rs2_data_fwd (ev1_rs2_data_fwd),
    .od0_rs1_data_fwd (od0_rs1_data_fwd),
    .od0_rs2_data_fwd (od0_rs2_data_fwd),
    .od1_rs1_data_fwd (od1_rs1_data_fwd),
    .od1_rs2_data_fwd (od1_rs2_data_fwd),
    .i1_stall         (i1_stall)
  );

  even_lane_i0 u_ev0 (
    .enable     (ev0_enable_ex),
    .opcode     (ev0_opcode_ex),
    .funct3     (ev0_funct3_ex),
    .funct7     (ev0_funct7_ex),
    .rs1_data   (ev0_rs1_data_fwd),
    .rs2_data   (ev0_rs2_data_fwd),
    .imm        (ev0_imm_ex),
    .alu_result (ev0_alu_result)
  );

  even_lane_i1 u_ev1 (
    .enable     (ev1_enable_ex),
    .opcode     (ev1_opcode_ex),
    .funct3     (ev1_funct3_ex),
    .funct7     (ev1_funct7_ex),
    .rs1_data   (ev1_rs1_data_fwd),
    .rs2_data   (ev1_rs2_data_fwd),
    .imm        (ev1_imm_ex),
    .alu_result (ev1_alu_result)
  );

  odd_lane_i0 u_od0 (
    .enable     (od0_enable_ex),
    .opcode     (od0_opcode_ex),
    .funct3     (od0_funct3_ex),
    .rs1_data   (od0_rs1_data_fwd),
    .rs2_data   (od0_rs2_data_fwd),
    .imm        (od0_imm_ex),
    .pc         (od0_pc_ex),
    .unit_done  (od0_unit_done),
    .brch_taken (od0_brch_taken),
    .brch_pc    (od0_brch_pc),
    .mem_en     (od0_mem_en),
    .mem_act    (od0_mem_act),
    .mem_addr   (od0_mem_addr),
    .mem_wdata  (od0_mem_wdata),
    .mem_besel  (od0_mem_besel),
    .link_pc    (od0_link_pc),
    .alu_result (od0_alu_result)
  );

  odd_lane_i1 u_od1 (
    .enable     (od1_enable_ex),
    .opcode     (od1_opcode_ex),
    .funct3     (od1_funct3_ex),
    .rs1_data   (od1_rs1_data_fwd),
    .rs2_data   (od1_rs2_data_fwd),
    .imm        (od1_imm_ex),
    .pc         (od1_pc_ex),
    .brch_taken (od1_brch_taken),
    .brch_pc    (od1_brch_pc),
    .mem_en     (od1_mem_en),
    .mem_act    (od1_mem_act),
    .mem_addr   (od1_mem_addr),
    .mem_wdata  (od1_mem_wdata),
    .mem_besel  (od1_mem_besel),
    .link_pc    (od1_link_pc),
    .alu_result (od1_alu_result)
  );

  // -------------------------------------------------------------------------
  // EX/MEM — four lane copies in one pipeline register
  // -------------------------------------------------------------------------
  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .stall_ev0           (1'b0),
    .stall_ev1           (1'b0),
    .stall_od0           (1'b0),
    .stall_od1           (1'b0),
    .ev0_enable_ex       (ev0_enable_ex),
    .ev0_reg_write_ex    (i0_reg_write_ex),
    .ev0_rd_ex           (ev0_rd_ex),
    .ev0_alu_result_ex   (ev0_alu_result),
    .ev0_pc_ex           (i0_pc_ex),
    .ev1_enable_ex       (ev1_enable_ex),
    .ev1_reg_write_ex    (i1_reg_write_ex),
    .ev1_rd_ex           (ev1_rd_ex),
    .ev1_alu_result_ex   (ev1_alu_result),
    .ev1_pc_ex           (i1_pc_ex),
    .od0_enable_ex       (od0_enable_ex),
    .od0_reg_write_ex    (i0_reg_write_ex),
    .od0_rd_ex           (od0_rd_ex),
    .od0_brch_taken_ex   (od0_brch_taken),
    .od0_brch_pc_ex      (od0_brch_pc),
    .od0_mem_en_ex       (od0_mem_en),
    .od0_mem_act_ex      (od0_mem_act),
    .od0_mem_addr_ex     (od0_mem_addr),
    .od0_mem_wdata_ex    (od0_mem_wdata),
    .od0_mem_besel_ex    (od0_mem_besel),
    .od0_link_pc_ex      (od0_link_pc),
    .od0_alu_result_ex   (od0_alu_result),
    .od0_pc_ex           (i0_pc_ex),
    .od1_enable_ex       (od1_enable_ex),
    .od1_reg_write_ex    (i1_reg_write_ex),
    .od1_rd_ex           (od1_rd_ex),
    .od1_brch_taken_ex   (od1_brch_taken),
    .od1_brch_pc_ex      (od1_brch_pc),
    .od1_mem_en_ex       (od1_mem_en),
    .od1_mem_act_ex      (od1_mem_act),
    .od1_mem_addr_ex     (od1_mem_addr),
    .od1_mem_wdata_ex    (od1_mem_wdata),
    .od1_mem_besel_ex    (od1_mem_besel),
    .od1_link_pc_ex      (od1_link_pc),
    .od1_alu_result_ex   (od1_alu_result),
    .od1_pc_ex           (i1_pc_ex)
  );

endmodule
