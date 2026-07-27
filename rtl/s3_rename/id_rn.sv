`timescale 1ns / 1ps
//=====================================================================
// Project:      RISC-V Dual-Issue SIMD Processor
// Module:       ID/RN Pipeline Register (dual-issue)
// Description:  Decode → Rename boundary. Array ports [2]; lane 0 = even, 1 = odd.
//               Pass-through FFs only. stall holds; flush/rst clear.
//               Carries BHT snapshot (brch_state / state_valid) for ROB metadata.
//=====================================================================
import rv_dis_pkg::*;

module id_rn (
  input  logic      clk,
  input  logic      rst_n,
  input  logic      flush,
  input  logic      enable,
  input  logic      stall,

  // Decode → ID/RN (combinational from decode)
  input  logic      decode_valid_id [2],
  input  logic      lane_sel_id     [2],
  input  logic      reg_write_id    [2],
  input  logic      store_en_id     [2],
  input  logic      brch_en_id      [2],
  input  logic      state_valid_id  [2],
  input  br_state_t brch_state_id   [2],
  input  logic      rs1_use_id      [2],
  input  logic      rs2_use_id      [2],
  input  opcode_t   opcode_id       [2],
  input  funct3_t   funct3_id       [2],
  input  funct7_t   funct7_id       [2],
  input  gpr_addr_t rd_addr_id      [2],
  input  gpr_addr_t rs1_addr_id     [2],
  input  gpr_addr_t rs2_addr_id     [2],
  input  word_t     imm_id          [2],
  input  word_t     pc_id           [2],
  input  logic      spec_en_id      [2],

  // ID/RN → Rename (registered)
  output logic      valid_rn        [2],
  output logic      lane_sel_rn     [2],
  output logic      reg_write_rn    [2],
  output logic      store_en_rn     [2],
  output logic      brch_en_rn      [2],
  output logic      state_valid_rn  [2],
  output br_state_t brch_state_rn   [2],
  output logic      rs1_use_rn      [2],
  output logic      rs2_use_rn      [2],
  output opcode_t   opcode_rn       [2],
  output funct3_t   funct3_rn       [2],
  output funct7_t   funct7_rn       [2],
  output gpr_addr_t rd_addr_rn      [2],
  output gpr_addr_t rs1_addr_rn     [2],
  output gpr_addr_t rs2_addr_rn     [2],
  output word_t     imm_rn          [2],
  output word_t     pc_rn           [2],
  output logic      spec_en_rn      [2]
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int i = 0; i < N_DUAL; i++) begin
        valid_rn[i]       <= 1'b0;
        lane_sel_rn[i]    <= 1'b0;
        reg_write_rn[i]   <= 1'b0;
        store_en_rn[i]    <= 1'b0;
        brch_en_rn[i]     <= 1'b0;
        state_valid_rn[i] <= 1'b0;
        brch_state_rn[i]  <= '0;
        rs1_use_rn[i]     <= 1'b0;
        rs2_use_rn[i]     <= 1'b0;
        opcode_rn[i]      <= '0;
        funct3_rn[i]      <= '0;
        funct7_rn[i]      <= '0;
        rd_addr_rn[i]     <= '0;
        rs1_addr_rn[i]    <= '0;
        rs2_addr_rn[i]    <= '0;
        imm_rn[i]         <= '0;
        pc_rn[i]          <= '0;
        spec_en_rn[i]     <= 1'b0;
      end
    end else if (enable && !stall) begin
      for (int i = 0; i < N_DUAL; i++) begin
        valid_rn[i]       <= decode_valid_id[i];
        lane_sel_rn[i]    <= lane_sel_id[i];
        reg_write_rn[i]   <= reg_write_id[i];
        store_en_rn[i]    <= store_en_id[i];
        brch_en_rn[i]     <= brch_en_id[i];
        state_valid_rn[i] <= state_valid_id[i];
        brch_state_rn[i]  <= brch_state_id[i];
        rs1_use_rn[i]     <= rs1_use_id[i];
        rs2_use_rn[i]     <= rs2_use_id[i];
        opcode_rn[i]      <= opcode_id[i];
        funct3_rn[i]      <= funct3_id[i];
        funct7_rn[i]      <= funct7_id[i];
        rd_addr_rn[i]     <= rd_addr_id[i];
        rs1_addr_rn[i]    <= rs1_addr_id[i];
        rs2_addr_rn[i]    <= rs2_addr_id[i];
        imm_rn[i]         <= imm_id[i];
        pc_rn[i]          <= pc_id[i];
        spec_en_rn[i]     <= spec_en_id[i];
      end
    end
  end

endmodule
