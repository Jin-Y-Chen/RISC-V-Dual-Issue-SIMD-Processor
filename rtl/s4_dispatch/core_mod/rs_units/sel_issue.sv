`timescale 1ns / 1ps

// Selector issue mux — fire+src=0 → bank[tag]; fire+src=1 → rename lane.
import rv_dis_pkg::*;
import rs_pkg::*;

module sel_issue (
  input  logic      bank_lane_sel [RS_WAYS],
  input  opcode_t   bank_opcode   [RS_WAYS],
  input  funct3_t   bank_funct3   [RS_WAYS],
  input  funct7_t   bank_funct7   [RS_WAYS],
  input  prf_addr_t bank_ps1      [RS_WAYS],
  input  prf_addr_t bank_ps2      [RS_WAYS],
  input  prf_addr_t bank_prd      [RS_WAYS],
  input  word_t     bank_imm      [RS_WAYS],
  input  word_t     bank_pc       [RS_WAYS],

  input  logic      lane_sel_dp [2],
  input  opcode_t   opcode_dp   [2],
  input  funct3_t   funct3_dp   [2],
  input  funct7_t   funct7_dp   [2],
  input  prf_addr_t ps1_dp      [2],
  input  prf_addr_t ps2_dp      [2],
  input  prf_addr_t prd_dp      [2],
  input  word_t     imm_dp      [2],
  input  word_t     pc_dp       [2],

  input  logic      fire   [2],
  input  logic      src    [2],   // 0=RS, 1=rename
  input  rs_way_t   rs_tag [2],   // bank way or rename lane id

  output logic      iss_valid    [2],
  output logic      iss_lane_sel [2],
  output opcode_t   iss_opcode   [2],
  output funct3_t   iss_funct3   [2],
  output funct7_t   iss_funct7   [2],
  output prf_addr_t iss_prd      [2],
  output word_t     iss_imm      [2],
  output word_t     iss_pc       [2],
  output prf_addr_t ps1_prf      [2],
  output prf_addr_t ps2_prf      [2]
);

  always_comb begin
    for (int i = 0; i < 2; i++) begin
      int d;
      d = int'(rs_tag[i][0]);
      iss_valid[i] = fire[i];
      if (fire[i] && src[i]) begin
        iss_lane_sel[i] = lane_sel_dp[d];
        iss_opcode[i]   = opcode_dp[d];
        iss_funct3[i]   = funct3_dp[d];
        iss_funct7[i]   = funct7_dp[d];
        iss_prd[i]      = prd_dp[d];
        iss_imm[i]      = imm_dp[d];
        iss_pc[i]       = pc_dp[d];
        ps1_prf[i]      = ps1_dp[d];
        ps2_prf[i]      = ps2_dp[d];
      end else if (fire[i]) begin
        iss_lane_sel[i] = bank_lane_sel[rs_tag[i]];
        iss_opcode[i]   = bank_opcode[rs_tag[i]];
        iss_funct3[i]   = bank_funct3[rs_tag[i]];
        iss_funct7[i]   = bank_funct7[rs_tag[i]];
        iss_prd[i]      = bank_prd[rs_tag[i]];
        iss_imm[i]      = bank_imm[rs_tag[i]];
        iss_pc[i]       = bank_pc[rs_tag[i]];
        ps1_prf[i]      = bank_ps1[rs_tag[i]];
        ps2_prf[i]      = bank_ps2[rs_tag[i]];
      end else begin
        iss_lane_sel[i] = 1'b0;
        iss_opcode[i]   = '0;
        iss_funct3[i]   = '0;
        iss_funct7[i]   = '0;
        iss_prd[i]      = '0;
        iss_imm[i]      = '0;
        iss_pc[i]       = '0;
        ps1_prf[i]      = '0;
        ps2_prf[i]      = '0;
      end
    end
  end

endmodule
