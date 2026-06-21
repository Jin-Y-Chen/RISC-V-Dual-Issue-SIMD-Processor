`timescale 1ns / 1ps

// RV-DIS scalar core: fetch top + decode top + ID/EX dispatch through MEM/WB.
module risc_dis_unit
  import rv_dis_pkg::*;
#(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,

  // internal controls
  input  logic        flush,

  // output data
  output logic [31:0] pc_fetch,
  output logic [31:0] pc_fetch_plus4,
  output logic        stall_id
);

  // -------------------------------------------------------------------------
  // Fetch — PC + instruction cache (dual-issue pair)
  // -------------------------------------------------------------------------
  logic        set;
  logic [31:0] set_pc;
  logic        i0_valid_wb;
  logic        i1_valid_wb;
  logic [31:0] i0_target_wb;
  logic [31:0] i1_target_wb;

  logic [31:0] i0_instr_if;
  logic [31:0] i1_instr_if;
  logic [31:0] i0_pc_if;
  logic [31:0] i1_pc_if;
  logic [31:0] i0_pc_target_if;
  logic [31:0] i1_pc_target_if;

  logic [31:0] i0_instr_id;
  logic [31:0] i1_instr_id;
  logic [31:0] i0_pc_id;
  logic [31:0] i1_pc_id;
  logic [31:0] i0_pc_target_id;
  logic [31:0] i1_pc_target_id;

  assign set           = 1'b0;
  assign set_pc         = 32'd0;
  assign i0_valid_wb   = 1'b0;  // tie resolved branch/jump retire here
  assign i1_valid_wb   = 1'b0;
  assign i0_target_wb  = 32'd0;
  assign i1_target_wb  = 32'd0;
  assign i0_pc_if      = pc_fetch;
  assign i1_pc_if      = pc_fetch_plus4;

  s1_fetch_struc #(
    .RESET_PC(RESET_PC)
  ) u_fetch (
    // external controls
    .clk           (clk),
    .rst_n         (rst_n),
    .enable        (enable),
    // internal controls
    .stall_i       (stall_id),
    .set            (set),
    // input data
    .set_pc         (set_pc),
    .i0_valid_wb    (i0_valid_wb),
    .i1_valid_wb    (i1_valid_wb),
    .i0_pc_wb       (i0_pc_wb),
    .i1_pc_wb       (i1_pc_wb),
    .i0_target_wb   (i0_target_wb),
    .i1_target_wb   (i1_target_wb),
    // output data
    .pc0           (pc_fetch),
    .pc1           (pc_fetch_plus4),
    .i0_pc_target  (i0_pc_target_if),
    .i1_pc_target  (i1_pc_target_if),
    .instr0        (i0_instr_if),
    .instr1        (i1_instr_if)
  );

  if_id u_if_id (
    // external controls
    .clk              (clk),
    .rst_n            (rst_n),
    .enable           (enable),
    // internal controls
    .flush            (flush),
    .stall            (stall_id),
    // input data
    .i0_instr_if      (i0_instr_if),
    .i1_instr_if      (i1_instr_if),
    .i0_pc_if         (i0_pc_if),
    .i1_pc_if         (i1_pc_if),
    .i0_pc_target_if  (i0_pc_target_if),
    .i1_pc_target_if  (i1_pc_target_if),
    // output data
    .i0_instr_id      (i0_instr_id),
    .i1_instr_id      (i1_instr_id),
    .i0_pc_id         (i0_pc_id),
    .i1_pc_id         (i1_pc_id),
    .i0_pc_target_id  (i0_pc_target_id),
    .i1_pc_target_id  (i1_pc_target_id)
  );

  // -------------------------------------------------------------------------
  // Decode — dual decoder + GPR
  // -------------------------------------------------------------------------
  logic        i0_valid_dec;
  logic        i0_brch_en_dec;
  lane_sel_e   i0_lane_sel_dec;
  logic [6:0]  i0_opcode_dec;
  logic [2:0]  i0_funct3_dec;
  logic [6:0]  i0_funct7_dec;
  logic [4:0]  i0_rd_dec;
  logic [4:0]  i0_rs1_dec;
  logic [4:0]  i0_rs2_dec;
  logic [31:0] i0_imm_dec;
  logic        i0_reg_write_dec;

  logic        i1_valid_dec;
  logic        i1_brch_en_dec;
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

  reg_t i0_rs1_data;
  reg_t i0_rs2_data;
  reg_t i1_rs1_data;
  reg_t i1_rs2_data;

  logic        i0_reg_write_wb;
  logic [4:0]  i0_rd_addr_wb;
  logic [31:0] i0_wdata_wb;
  logic [31:0] i0_pc_wb;
  logic        i1_reg_write_wb;
  logic [4:0]  i1_rd_addr_wb;
  logic [31:0] i1_wdata_wb;
  logic [31:0] i1_pc_wb;

  s2_decode_struct u_decode (
    // external controls
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
    // internal controls
    .i0_wen          (i0_reg_write_wb),
    .i1_wen          (i1_reg_write_wb),
    // input data
    .i0_instr        (i0_instr_id),
    .i1_instr        (i1_instr_id),
    .i0_rd           (i0_rd_addr_wb),
    .i0_wdata        (i0_wdata_wb),
    .i0_wpc          (i0_pc_wb),
    .i1_rd           (i1_rd_addr_wb),
    .i1_wdata        (i1_wdata_wb),
    .i1_wpc          (i1_pc_wb),
    // output data
    .i0_lane_sel     (i0_lane_sel_dec),
    .i0_opcode       (i0_opcode_dec),
    .i0_funct3       (i0_funct3_dec),
    .i0_funct7       (i0_funct7_dec),
    .i0_rd_addr      (i0_rd_dec),
    .i0_rs1_addr     (i0_rs1_dec),
    .i0_rs2_addr     (i0_rs2_dec),
    .i0_imm          (i0_imm_dec),
    .i0_rs1_data     (i0_rs1_data),
    .i0_rs2_data     (i0_rs2_data),
    .i1_lane_sel     (i1_lane_sel_dec),
    .i1_opcode       (i1_opcode_dec),
    .i1_funct3       (i1_funct3_dec),
    .i1_funct7       (i1_funct7_dec),
    .i1_rd_addr      (i1_rd_dec),
    .i1_rs1_addr     (i1_rs1_dec),
    .i1_rs2_addr     (i1_rs2_dec),
    .i1_imm          (i1_imm_dec),
    .i1_rs1_data     (i1_rs1_data),
    .i1_rs2_data     (i1_rs2_data),
    // output controls
    .i0_valid        (i0_valid_dec),
    .i0_brch_en     (i0_brch_en_dec),
    .i0_reg_write    (i0_reg_write_dec),
    .i1_valid        (i1_valid_dec),
    .i1_brch_en     (i1_brch_en_dec),
    .i1_rs1_use      (i1_rs1_use_dec),
    .i1_rs2_use      (i1_rs2_use_dec),
    .i1_reg_write    (i1_reg_write_dec)
  );

  // Same-bundle / in-flight GPR RAW: id_ex_dispatch scoreboard (stall_id, I1 hold replay).

  // -------------------------------------------------------------------------
  // ID/EX dispatch — fixed slot map into four lane copies
  // -------------------------------------------------------------------------
  logic        ev0_reg_write_exwb;
  logic [4:0]  ev0_rd_addr_exwb;
  logic [31:0] ev0_wdata_exwb;
  logic [31:0] ev0_pc_exwb;
  logic        ev1_reg_write_exwb;
  logic [4:0]  ev1_rd_addr_exwb;
  logic [31:0] ev1_wdata_exwb;
  logic [31:0] ev1_pc_exwb;

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

  id_ex_dispatch u_dispatch (
    .clk             (clk),
    .rst_n           (rst_n),
    .enable          (enable),
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
  // Execute — forward unit + four lanes 
  // -------------------------------------------------------------------------
  logic [31:0] ev0_alu_result;
  logic [31:0] ev1_alu_result;

  logic        od0_use_link_ex;
  logic        od1_use_link_ex;
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

  s3_execute_struct u_execute (
    // internal controls
    .i0_reg_write_ex     (i0_reg_write_ex),
    .i1_reg_write_ex     (i1_reg_write_ex),
    .ev0_enable_ex       (ev0_enable_ex),
    .ev1_enable_ex       (ev1_enable_ex),
    .od0_enable_ex       (od0_enable_ex),
    .od1_enable_ex       (od1_enable_ex),
    .wb0_reg_write       (i0_reg_write_wb),
    .wb1_reg_write       (i1_reg_write_wb),
    // input data
    .i0_pc_ex            (i0_pc_ex),
    .i1_pc_ex            (i1_pc_ex),
    .ev0_opcode_ex       (ev0_opcode_ex),
    .ev0_funct3_ex       (ev0_funct3_ex),
    .ev0_funct7_ex       (ev0_funct7_ex),
    .ev0_rd_ex           (ev0_rd_ex),
    .ev0_rs1_addr_ex     (ev0_rs1_addr_ex),
    .ev0_rs2_addr_ex     (ev0_rs2_addr_ex),
    .ev0_imm_ex          (ev0_imm_ex),
    .ev0_rs1_data_ex     (ev0_rs1_data_ex),
    .ev0_rs2_data_ex     (ev0_rs2_data_ex),
    .ev0_pc_ex           (ev0_pc_ex),
    .ev1_opcode_ex       (ev1_opcode_ex),
    .ev1_funct3_ex       (ev1_funct3_ex),
    .ev1_funct7_ex       (ev1_funct7_ex),
    .ev1_rd_ex           (ev1_rd_ex),
    .ev1_rs1_addr_ex     (ev1_rs1_addr_ex),
    .ev1_rs2_addr_ex     (ev1_rs2_addr_ex),
    .ev1_imm_ex          (ev1_imm_ex),
    .ev1_rs1_data_ex     (ev1_rs1_data_ex),
    .ev1_rs2_data_ex     (ev1_rs2_data_ex),
    .ev1_pc_ex           (ev1_pc_ex),
    .od0_opcode_ex       (od0_opcode_ex),
    .od0_funct3_ex       (od0_funct3_ex),
    .od0_rd_ex           (od0_rd_ex),
    .od0_rs1_addr_ex     (od0_rs1_addr_ex),
    .od0_rs2_addr_ex     (od0_rs2_addr_ex),
    .od0_imm_ex          (od0_imm_ex),
    .od0_rs1_data_ex     (od0_rs1_data_ex),
    .od0_rs2_data_ex     (od0_rs2_data_ex),
    .od0_pc_ex           (od0_pc_ex),
    .od1_opcode_ex       (od1_opcode_ex),
    .od1_funct3_ex       (od1_funct3_ex),
    .od1_rd_ex           (od1_rd_ex),
    .od1_rs1_addr_ex     (od1_rs1_addr_ex),
    .od1_rs2_addr_ex     (od1_rs2_addr_ex),
    .od1_imm_ex          (od1_imm_ex),
    .od1_rs1_data_ex     (od1_rs1_data_ex),
    .od1_rs2_data_ex     (od1_rs2_data_ex),
    .od1_pc_ex           (od1_pc_ex),
    .wb0_rd_addr         (i0_rd_addr_wb),
    .wb0_data            (i0_wdata_wb),
    .wb0_pc              (i0_pc_wb),
    .wb1_rd_addr         (i1_rd_addr_wb),
    .wb1_data            (i1_wdata_wb),
    .wb1_pc              (i1_pc_wb),
    // output controls
    .od0_use_link_ex     (od0_use_link_ex),
    .od1_use_link_ex     (od1_use_link_ex),
    .od0_brch_taken      (od0_brch_taken),
    .od0_mem_en          (od0_mem_en),
    .od0_mem_act         (od0_mem_act),
    .od1_brch_taken      (od1_brch_taken),
    .od1_mem_en          (od1_mem_en),
    .od1_mem_act         (od1_mem_act),
    // output data
    .ev0_alu_result      (ev0_alu_result),
    .ev1_alu_result      (ev1_alu_result),
    .od0_brch_pc         (od0_brch_pc),
    .od0_mem_addr        (od0_mem_addr),
    .od0_mem_wdata       (od0_mem_wdata),
    .od0_mem_besel       (od0_mem_besel),
    .od0_link_pc         (od0_link_pc),
    .od0_alu_result      (od0_alu_result),
    .od1_brch_pc         (od1_brch_pc),
    .od1_mem_addr        (od1_mem_addr),
    .od1_mem_wdata       (od1_mem_wdata),
    .od1_mem_besel       (od1_mem_besel),
    .od1_link_pc         (od1_link_pc),
    .od1_alu_result      (od1_alu_result)
  );

  // -------------------------------------------------------------------------
  // EX/MEM — odd-lane pipeline register
  // -------------------------------------------------------------------------
  ex_mem u_ex_mem (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
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
  // Memory — L1 data cache
  // -------------------------------------------------------------------------
  logic        dcache_busy;

  s4_memory_struct u_memory (
    // external controls
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    // internal controls
    .od0_mem_en_mem    (od0_mem_en_mem),
    .od0_mem_act_mem   (od0_mem_act_mem),
    .od1_mem_en_mem    (od1_mem_en_mem),
    .od1_mem_act_mem   (od1_mem_act_mem),
    // input data
    .od0_mem_addr_mem  (od0_mem_addr_mem),
    .od0_mem_wdata_mem (od0_mem_wdata_mem),
    .od0_mem_besel_mem (od0_mem_besel_mem),
    .od1_mem_addr_mem  (od1_mem_addr_mem),
    .od1_mem_wdata_mem (od1_mem_wdata_mem),
    .od1_mem_besel_mem (od1_mem_besel_mem),
    // output data
    .od0_load_mem_data (od0_load_mem_data),
    .od1_load_mem_data (od1_load_mem_data),
    // output controls
    .dcache_busy       (dcache_busy)
  );

  // -------------------------------------------------------------------------
  // EX/WB + MEM/WB — even EX bank + odd MEM bank (ex_mem_wb)
  // -------------------------------------------------------------------------
  ex_mem_wb u_ex_mem_wb (
    .clk                (clk),
    .rst_n              (rst_n),
    .enable             (enable),
    .flush              (flush),
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
