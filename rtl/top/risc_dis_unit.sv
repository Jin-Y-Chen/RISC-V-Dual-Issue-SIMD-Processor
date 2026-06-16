`timescale 1ns / 1ps

// RV-DIS scalar core slice: ID through MEM/WB (no fetch yet).
// Dual decoders + GPR + ID/EX dispatch + forward unit + four lane copies.
// Even-lane ALU uses ex_mem_wb EX bank; odd-lane uses ex_mem → ex_mem_wb MEM bank.
// WB retire: ex_mem_wb push candidates drive GPR i0/i1 write ports directly.
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
  input  logic [31:0] i1_pc_id
);

  // Same-bundle / in-flight GPR RAW: id_ex_dispatch scoreboard (stall_id, I1 hold replay).

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
  // Register file — WB from ex_mem_wb merged outputs
  // -------------------------------------------------------------------------
  logic        ev0_reg_write_exwb;
  logic [4:0]  ev0_rd_addr_exwb;
  logic [31:0] ev0_wdata_exwb;
  logic [31:0] ev0_pc_exwb;
  logic        ev1_reg_write_exwb;
  logic [4:0]  ev1_rd_addr_exwb;
  logic [31:0] ev1_wdata_exwb;
  logic [31:0] ev1_pc_exwb;

  logic        i0_reg_write_wb;
  logic [4:0]  i0_rd_addr_wb;
  logic [31:0] i0_wdata_wb;
  logic [31:0] i0_pc_wb;
  logic        i1_reg_write_wb;
  logic [4:0]  i1_rd_addr_wb;
  logic [31:0] i1_wdata_wb;
  logic [31:0] i1_pc_wb;

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
    .i0_wen      (i0_reg_write_wb),
    .i0_rd       (i0_rd_addr_wb),
    .i0_wdata    (i0_wdata_wb),
    .i0_wpc      (i0_pc_wb),
    .i1_wen      (i1_reg_write_wb),
    .i1_rd       (i1_rd_addr_wb),
    .i1_wdata    (i1_wdata_wb),
    .i1_wpc      (i1_pc_wb)
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

  logic        stall_id;
  logic [31:0] od0_load_mem_data;
  logic [31:0] od1_load_mem_data;
  logic [31:0] od0_wdata_mem_fwd;
  logic [31:0] od1_wdata_mem_fwd;

  logic        wb_push0_valid;
  logic [4:0]  wb_push0_rd;
  logic [31:0] wb_push0_wdata;
  logic [31:0] wb_push0_pc;
  logic        wb_push1_valid;
  logic [4:0]  wb_push1_rd;
  logic [31:0] wb_push1_wdata;
  logic [31:0] wb_push1_pc;

  assign od0_load_mem_data = 32'd0;  // tie memory_cache load return here
  assign od1_load_mem_data = 32'd0;

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
    .i0_rs1_use_id   (i0_rs1_use_dec),
    .i0_rs2_use_id   (i0_rs2_use_dec),
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
    .i1_rs1_use_id   (i1_rs1_use_dec),
    .i1_rs2_use_id   (i1_rs2_use_dec),
    .i1_reg_write_id (i1_reg_write_dec),
    .i1_imm_id       (i1_imm_dec),
    .i1_rs1_data_id  (i1_rs1_data),
    .i1_rs2_data_id  (i1_rs2_data),
    .i1_pc_id        (i1_pc_id),
    .stall_id        (stall_id),
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

  logic        od0_use_link_ex;
  logic        od1_use_link_ex;

  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;

  assign od0_use_link_ex = od0_enable_ex &&
                           ((od0_opcode_ex == OPC_JAL) || (od0_opcode_ex == OPC_JALR));
  assign od1_use_link_ex = od1_enable_ex &&
                           ((od1_opcode_ex == OPC_JAL) || (od1_opcode_ex == OPC_JALR));

  // -------------------------------------------------------------------------
  // Forward unit — WB wb0/wb1 -> EX operand bypass
  // -------------------------------------------------------------------------
  forward_unit u_forward (
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
    .wb0_reg_write    (i0_reg_write_wb),
    .wb0_rd_addr      (i0_rd_addr_wb),
    .wb0_data         (i0_wdata_wb),
    .wb0_pc           (i0_pc_wb),
    .wb1_reg_write    (i1_reg_write_wb),
    .wb1_rd_addr      (i1_rd_addr_wb),
    .wb1_data         (i1_wdata_wb),
    .wb1_pc           (i1_pc_wb),
    .ev0_rs1_data_fwd (ev0_rs1_data_fwd),
    .ev0_rs2_data_fwd (ev0_rs2_data_fwd),
    .ev1_rs1_data_fwd (ev1_rs1_data_fwd),
    .ev1_rs2_data_fwd (ev1_rs2_data_fwd),
    .od0_rs1_data_fwd (od0_rs1_data_fwd),
    .od0_rs2_data_fwd (od0_rs2_data_fwd),
    .od1_rs1_data_fwd (od1_rs1_data_fwd),
    .od1_rs2_data_fwd (od1_rs2_data_fwd)
  );

  even_lane u_ev0 (
    .enable     (ev0_enable_ex),
    .opcode     (ev0_opcode_ex),
    .funct3     (ev0_funct3_ex),
    .funct7     (ev0_funct7_ex),
    .rs1_data   (ev0_rs1_data_fwd),
    .rs2_data   (ev0_rs2_data_fwd),
    .imm        (ev0_imm_ex),
    .alu_result (ev0_alu_result)
  );

  even_lane u_ev1 (
    .enable     (ev1_enable_ex),
    .opcode     (ev1_opcode_ex),
    .funct3     (ev1_funct3_ex),
    .funct7     (ev1_funct7_ex),
    .rs1_data   (ev1_rs1_data_fwd),
    .rs2_data   (ev1_rs2_data_fwd),
    .imm        (ev1_imm_ex),
    .alu_result (ev1_alu_result)
  );

  odd_lane u_od0 (
    .enable     (od0_enable_ex),
    .opcode     (od0_opcode_ex),
    .funct3     (od0_funct3_ex),
    .rs1_data   (od0_rs1_data_fwd),
    .rs2_data   (od0_rs2_data_fwd),
    .imm        (od0_imm_ex),
    .pc         (od0_pc_ex),
    .brch_taken (od0_brch_taken),
    .brch_pc    (od0_brch_pc),
    .mem_en     (od0_mem_en),
    .mem_act    (od0_mem_act),
    .mem_addr   (od0_mem_addr),
    .mem_wdata  (od0_mem_wdata),
    .mem_besel  (od0_mem_besel),
    .link_pc    (od0_link_pc),
    .reg_wdata  (od0_alu_result)
  );

  odd_lane u_od1 (
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
    .reg_wdata  (od1_alu_result)
  );

  // -------------------------------------------------------------------------
  // EX/MEM — odd-lane only; even ALU skips this register
  // -------------------------------------------------------------------------
  logic        od0_use_link_mem;
  logic        od1_use_link_mem;
  logic        od0_reg_write_mem;
  logic [4:0]  od0_rd_mem;
  logic        od0_brch_taken_mem;
  logic [31:0] od0_brch_pc_mem;
  logic        od0_mem_en_mem;
  logic        od0_mem_act_mem;
  logic [31:0] od0_mem_addr_mem;
  logic [31:0] od0_mem_wdata_mem;
  logic [3:0]  od0_mem_besel_mem;
  logic [31:0] od0_link_pc_mem;
  logic [31:0] od0_alu_result_mem;
  logic [31:0] od0_pc_mem;

  logic        od1_reg_write_mem;
  logic [4:0]  od1_rd_mem;
  logic        od1_brch_taken_mem;
  logic [31:0] od1_brch_pc_mem;
  logic        od1_mem_en_mem;
  logic        od1_mem_act_mem;
  logic [31:0] od1_mem_addr_mem;
  logic [31:0] od1_mem_wdata_mem;
  logic [3:0]  od1_mem_besel_mem;
  logic [31:0] od1_link_pc_mem;
  logic [31:0] od1_alu_result_mem;
  logic [31:0] od1_pc_mem;

  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .stall_od0           (1'b0),
    .stall_od1           (1'b0),
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
    .od0_use_link_ex     (od0_use_link_ex),
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
    .od1_use_link_ex     (od1_use_link_ex),
    .od1_pc_ex           (i1_pc_ex),
    .od0_reg_write_mem   (od0_reg_write_mem),
    .od0_rd_mem          (od0_rd_mem),
    .od0_brch_taken_mem  (od0_brch_taken_mem),
    .od0_brch_pc_mem     (od0_brch_pc_mem),
    .od0_mem_en_mem      (od0_mem_en_mem),
    .od0_mem_act_mem     (od0_mem_act_mem),
    .od0_mem_addr_mem    (od0_mem_addr_mem),
    .od0_mem_wdata_mem   (od0_mem_wdata_mem),
    .od0_mem_besel_mem   (od0_mem_besel_mem),
    .od0_link_pc_mem     (od0_link_pc_mem),
    .od0_alu_result_mem  (od0_alu_result_mem),
    .od0_use_link_mem    (od0_use_link_mem),
    .od0_pc_mem          (od0_pc_mem),
    .od1_reg_write_mem   (od1_reg_write_mem),
    .od1_rd_mem          (od1_rd_mem),
    .od1_brch_taken_mem  (od1_brch_taken_mem),
    .od1_brch_pc_mem     (od1_brch_pc_mem),
    .od1_mem_en_mem      (od1_mem_en_mem),
    .od1_mem_act_mem     (od1_mem_act_mem),
    .od1_mem_addr_mem    (od1_mem_addr_mem),
    .od1_mem_wdata_mem   (od1_mem_wdata_mem),
    .od1_mem_besel_mem   (od1_mem_besel_mem),
    .od1_link_pc_mem     (od1_link_pc_mem),
    .od1_alu_result_mem  (od1_alu_result_mem),
    .od1_use_link_mem    (od1_use_link_mem),
    .od1_pc_mem          (od1_pc_mem)
  );

  // -------------------------------------------------------------------------
  // EX/WB + MEM/WB — even EX bank + odd MEM bank (ex_mem_wb)
  // -------------------------------------------------------------------------
  ex_mem_wb u_ex_mem_wb (
    .clk                (clk),
    .rst_n              (rst_n),
    .flush              (flush),
    .stall_i0           (1'b0),
    .stall_i1           (1'b0),
    .ev0_reg_write_ex   (ev0_enable_ex && i0_reg_write_ex),
    .ev0_rd_addr_ex     (ev0_rd_ex),
    .ev0_wdata_ex       (ev0_alu_result),
    .ev0_pc_ex          (i0_pc_ex),
    .ev1_reg_write_ex   (ev1_enable_ex && i1_reg_write_ex),
    .ev1_rd_addr_ex     (ev1_rd_ex),
    .ev1_wdata_ex       (ev1_alu_result),
    .ev1_pc_ex          (i1_pc_ex),
    .od0_reg_write_mem  (od0_reg_write_mem),
    .od0_rd_addr_mem    (od0_rd_mem),
    .od0_pc_mem         (od0_pc_mem),
    .od0_use_link_mem   (od0_use_link_mem),
    .od0_alu_result_mem (od0_alu_result_mem),
    .od0_mem_en_mem     (od0_mem_en_mem),
    .od0_mem_act_mem    (od0_mem_act_mem),
    .od0_load_mem_data     (od0_load_mem_data),
    .od1_reg_write_mem  (od1_reg_write_mem),
    .od1_rd_addr_mem    (od1_rd_mem),
    .od1_pc_mem         (od1_pc_mem),
    .od1_use_link_mem   (od1_use_link_mem),
    .od1_alu_result_mem (od1_alu_result_mem),
    .od1_mem_en_mem     (od1_mem_en_mem),
    .od1_mem_act_mem    (od1_mem_act_mem),
    .od1_load_mem_data     (od1_load_mem_data),
    .ev0_reg_write_exwb (ev0_reg_write_exwb),
    .ev0_rd_addr_exwb   (ev0_rd_addr_exwb),
    .ev0_wdata_exwb     (ev0_wdata_exwb),
    .ev0_pc_exwb        (ev0_pc_exwb),
    .ev1_reg_write_exwb (ev1_reg_write_exwb),
    .ev1_rd_addr_exwb   (ev1_rd_addr_exwb),
    .ev1_wdata_exwb     (ev1_wdata_exwb),
    .ev1_pc_exwb        (ev1_pc_exwb),
    .od0_wdata_mem      (od0_wdata_mem_fwd),
    .od1_wdata_mem      (od1_wdata_mem_fwd),
    .push0_valid        (wb_push0_valid),
    .push0_rd           (wb_push0_rd),
    .push0_wdata        (wb_push0_wdata),
    .push0_pc           (wb_push0_pc),
    .push1_valid        (wb_push1_valid),
    .push1_rd           (wb_push1_rd),
    .push1_wdata        (wb_push1_wdata),
    .push1_pc           (wb_push1_pc)
  );

  assign i0_reg_write_wb = wb_push0_valid;
  assign i0_rd_addr_wb   = wb_push0_rd;
  assign i0_wdata_wb     = wb_push0_wdata;
  assign i0_pc_wb        = wb_push0_pc;
  assign i1_reg_write_wb = wb_push1_valid;
  assign i1_rd_addr_wb   = wb_push1_rd;
  assign i1_wdata_wb     = wb_push1_wdata;
  assign i1_pc_wb        = wb_push1_pc;

endmodule
