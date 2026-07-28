`timescale 1ns / 1ps

// RN/DP pipeline register — renamed tags/controls held while RS is full.
// Dual-issue ports are [2] arrays: index 0 = I0, index 1 = I1.
// Latches ROB valid + RAT source-ready with renamed tags for the RS.
// reg_write is implied by prd != 0 (rename zeros prd for non-writes).
import rv_dis_pkg::*;

module rn_dp (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall_dp,
  output logic        stall_rn,

  input  logic        rob_valid_rn   [2],
  input  logic        path_use_rn    [2],
  input  logic        lane_sel_rn    [2],
  input  opcode_t     opcode_rn      [2],
  input  funct3_t     funct3_rn      [2],
  input  funct7_t     funct7_rn      [2],
  input  prf_addr_t   ps1_tag_rn     [2],
  input  prf_addr_t   ps2_tag_rn     [2],
  input  prf_addr_t   rob_tag_rn     [2],
  input  word_t       imm_rn         [2],
  input  word_t       pc_rn          [2],

  output logic        rob_valid_dp   [2],
  output logic        path_use_dp    [2],
  output logic        lane_sel_dp    [2],
  output opcode_t     opcode_dp      [2],
  output funct3_t     funct3_dp      [2],
  output funct7_t     funct7_dp      [2],
  output prf_addr_t   ps1_tag_dp     [2],
  output prf_addr_t   ps2_tag_dp     [2],
  output prf_addr_t   rob_tag_dp     [2],
  output word_t       imm_dp         [2],
  output word_t       pc_dp          [2]
);

  assign stall_rn = stall_dp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int i = 0; i < N_DUAL; i++) begin
        rob_valid_dp[i]  <= 1'b0;
        path_use_dp[i]   <= 1'b0;
        lane_sel_dp[i]   <= 1'b0;
        opcode_dp[i]     <= '0;
        funct3_dp[i]     <= '0;
        funct7_dp[i]     <= '0;
        ps1_tag_dp[i]    <= '0;
        ps2_tag_dp[i]    <= '0;
        rob_tag_dp[i]    <= '0;
        imm_dp[i]        <= '0;
        pc_dp[i]         <= '0;
      end
    end else if (enable && !stall_dp) begin
      for (int i = 0; i < N_DUAL; i++) begin
        rob_valid_dp[i]  <= rob_valid_rn[i];
        path_use_dp[i]   <= path_use_rn[i];
        lane_sel_dp[i]   <= lane_sel_rn[i];
        opcode_dp[i]     <= opcode_rn[i];
        funct3_dp[i]     <= funct3_rn[i];
        funct7_dp[i]     <= funct7_rn[i];
        ps1_tag_dp[i]    <= ps1_tag_rn[i];
        ps2_tag_dp[i]    <= ps2_tag_rn[i];
        rob_tag_dp[i]    <= rob_tag_rn[i];
        imm_dp[i]        <= imm_rn[i];
        pc_dp[i]         <= pc_rn[i];
      end
    end
  end

endmodule
