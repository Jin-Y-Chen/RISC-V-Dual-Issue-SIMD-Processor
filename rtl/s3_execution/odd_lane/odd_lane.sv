// Top-level odd execution lane: scalar mem/control + 128-bit vector LSU.
module odd_lane
  import spu_lite_pkg::*;
(
  input  logic        valid,
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [4:0]  rd,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [31:0] imm,
  input  logic [31:0] pc,
  input  vreg_t       vs_data,

  output logic        branch_taken,
  output logic [31:0] branch_target,
  output logic        jump,
  output logic [31:0] jump_target,
  output logic        mem_read,
  output logic        mem_write,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_be,
  output logic        reg_write,
  output logic [4:0]  rd_out,
  output logic [31:0] link_data,
  output logic        vec_mem_read,
  output logic        vec_mem_write,
  output logic [31:0] vec_mem_addr,
  output logic [15:0] vec_mem_be,
  output vreg_t       vec_mem_wdata,
  output logic        vreg_write,
  output logic [2:0]  vd_out,
  output logic        vec_addr_misaligned
);

  logic        branch_cond;
  logic        vec_valid;
  logic        vec_is_store;
  logic [31:0] scalar_addr;
  logic [3:0]  scalar_be;

  assign vec_valid    = valid && is_vec_mem(opcode);
  assign vec_is_store = vec_valid && (funct3 == F3_VST128);

  branch_unit u_branch (
    .funct3       (funct3),
    .rs1_data     (rs1_data),
    .rs2_data     (rs2_data),
    .branch_taken (branch_cond)
  );

  address_gen u_scalar_addr (
    .funct3    (funct3),
    .is_store  (valid && (opcode == OPC_STORE)),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .imm       (imm),
    .mem_addr  (scalar_addr),
    .mem_wdata (mem_wdata),
    .mem_be    (scalar_be)
  );

  vector_lsu_128 u_vec_lsu (
    .is_store         (vec_is_store),
    .base_addr        (rs1_data),
    .imm              (imm),
    .vs_data          (vs_data),
    .mem_addr         (vec_mem_addr),
    .mem_be           (vec_mem_be),
    .mem_wdata        (vec_mem_wdata),
    .addr_misaligned  (vec_addr_misaligned)
  );

  assign mem_read  = valid && (opcode == OPC_LOAD);
  assign mem_write = valid && (opcode == OPC_STORE);
  assign mem_addr  = scalar_addr;
  assign mem_be    = scalar_be;

  assign vec_mem_read  = vec_valid && (funct3 == F3_VLD128);
  assign vec_mem_write = vec_is_store;
  assign vreg_write    = vec_mem_read;
  assign vd_out        = vreg_idx(rd);
  // VST128: vector source index is in instr[24:20]; RF read presents vs_data

  assign branch_taken  = valid && (opcode == OPC_BRANCH) && branch_cond;
  assign branch_target = pc + imm;

  assign jump        = valid && (opcode == OPC_JAL || opcode == OPC_JALR);
  assign jump_target = (opcode == OPC_JALR) ? ((rs1_data + imm) & 32'hFFFFFFFE) : (pc + imm);

  assign reg_write = valid && (
    (opcode == OPC_LOAD) ||
    (opcode == OPC_JAL) ||
    (opcode == OPC_JALR)
  ) && (rd != 5'd0);

  assign rd_out    = rd;
  assign link_data = pc + 32'd4;

endmodule
