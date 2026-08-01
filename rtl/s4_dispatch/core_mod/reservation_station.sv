`timescale 1ns / 1ps

// Reservation station — owns bank; ↓clk update from selector controls.
// Control per channel (src_en, store_en):
//   0,1 → write rename lane i into a free way
//   1,1 → bump bank_age[rs_tag] only
//   0,0 → nop
//   1,0 → clear bank[rs_tag]
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        path_en,
  input  logic        path_sel,
  input  logic        stall_dp,

  input  logic        valid_dp    [2],
  input  logic        lane_sel_dp [2],
  input  logic        path_use_dp [2],
  input  opcode_t     opcode_dp   [2],
  input  funct3_t     funct3_dp   [2],
  input  funct7_t     funct7_dp   [2],
  input  prf_addr_t   ps1_tag_dp  [2],
  input  prf_addr_t   ps2_tag_dp  [2],
  input  prf_addr_t   rob_tag_dp  [2],
  input  word_t       imm_dp      [2],
  input  word_t       pc_dp       [2],

  input  logic        wb_en       [2],
  input  prf_addr_t   rob_tag_wb  [2],

  input  logic        src_en   [2],
  input  logic        store_en [2],
  input  rs_way_t     rs_tag   [2],

  output logic        bank_valid    [RS_WAYS],
  output rs_way_t     bank_rs_tag   [RS_WAYS],
  output rs_age_t     bank_age      [RS_WAYS],
  output logic        bank_lane_sel [RS_WAYS],
  output logic        bank_spec     [RS_WAYS],
  output logic        bank_rs1_rdy  [RS_WAYS],
  output logic        bank_rs2_rdy  [RS_WAYS],
  output opcode_t     bank_opcode   [RS_WAYS],
  output funct3_t     bank_funct3   [RS_WAYS],
  output funct7_t     bank_funct7   [RS_WAYS],
  output prf_addr_t   bank_ps1      [RS_WAYS],
  output prf_addr_t   bank_ps2      [RS_WAYS],
  output prf_addr_t   bank_prd      [RS_WAYS],
  output word_t       bank_imm      [RS_WAYS],
  output word_t       bank_pc       [RS_WAYS]
);

  logic bank_rs1_rdy_w [RS_WAYS];
  logic bank_rs2_rdy_w [RS_WAYS];

  rs_wakeup u_wakeup (
    .bank_valid_q   (bank_valid),
    .bank_rs1_rdy_q (bank_rs1_rdy),
    .bank_rs2_rdy_q (bank_rs2_rdy),
    .bank_ps1_q     (bank_ps1),
    .bank_ps2_q     (bank_ps2),
    .wb_en,
    .rob_tag_wb,
    .bank_rs1_rdy_w,
    .bank_rs2_rdy_w
  );

  function automatic logic path_ok(input int lane);
    return !path_en || (path_use_dp[lane] == path_sel);
  endfunction

  function automatic logic way_kill(input int i);
    logic clr;
    clr = 1'b0;
    if (enable)
      for (int ch = 0; ch < 2; ch++)
        if (src_en[ch] && !store_en[ch] && (rs_tag[ch] == rs_way_t'(i)))
          clr = 1'b1;
    return (bank_valid[i] && rs_wb_hit(bank_prd[i], wb_en, rob_tag_wb)) ||
           (path_en && bank_valid[i] && (bank_spec[i] != path_sel)) ||
           clr;
  endfunction

  task automatic clear_way(input int i);
    bank_valid[i]    <= 1'b0;
    bank_rs_tag[i]   <= '0;
    bank_age[i]      <= '0;
    bank_lane_sel[i] <= 1'b0;
    bank_spec[i]     <= 1'b0;
    bank_rs1_rdy[i]  <= 1'b0;
    bank_rs2_rdy[i]  <= 1'b0;
    bank_opcode[i]   <= '0;
    bank_funct3[i]   <= '0;
    bank_funct7[i]   <= '0;
    bank_ps1[i]      <= '0;
    bank_ps2[i]      <= '0;
    bank_prd[i]      <= '0;
    bank_imm[i]      <= '0;
    bank_pc[i]       <= '0;
  endtask

  task automatic write_way(
    input rs_way_t slot,
    input int      lane,
    input rs_age_t age,
    input logic    raw_rs1,
    input logic    raw_rs2
  );
    bank_valid[slot]    <= 1'b1;
    bank_rs_tag[slot]   <= slot;
    bank_age[slot]      <= age;
    bank_lane_sel[slot] <= lane_sel_dp[lane];
    bank_spec[slot]     <= path_use_dp[lane];
    bank_rs1_rdy[slot]  <= rs_alloc_src_rdy(
      ps1_tag_dp[lane], raw_rs1, bank_valid, bank_prd, wb_en, rob_tag_wb);
    bank_rs2_rdy[slot]  <= rs_alloc_src_rdy(
      ps2_tag_dp[lane], raw_rs2, bank_valid, bank_prd, wb_en, rob_tag_wb);
    bank_opcode[slot]   <= opcode_dp[lane];
    bank_funct3[slot]   <= funct3_dp[lane];
    bank_funct7[slot]   <= funct7_dp[lane];
    bank_ps1[slot]      <= ps1_tag_dp[lane];
    bank_ps2[slot]      <= ps2_tag_dp[lane];
    bank_prd[slot]      <= rob_tag_dp[lane];
    bank_imm[slot]      <= imm_dp[lane];
    bank_pc[slot]       <= pc_dp[lane];
  endtask

  always_ff @(negedge clk or negedge rst_n) begin
    rs_mask_t free_m, live;
    rs_way_t  free0, free1;
    rs_age_t  next_age;
    logic     wr0, wr1, raw_rs1, raw_rs2;

    if (!rst_n || flush) begin
      for (int i = 0; i < RS_WAYS; i++)
        clear_way(i);
    end else begin
      // Wakeup + kill (WB / path / issued clear).
      for (int i = 0; i < RS_WAYS; i++) begin
        if (way_kill(i))
          clear_way(i);
        else begin
          bank_rs1_rdy[i] <= bank_rs1_rdy_w[i];
          bank_rs2_rdy[i] <= bank_rs2_rdy_w[i];
        end
      end

      if (enable) begin
        // Age bump for unpicked RS (src_en && store_en).
        for (int i = 0; i < RS_WAYS; i++)
          live[i] = bank_valid[i];
        for (int ch = 0; ch < 2; ch++)
          if (src_en[ch] && store_en[ch])
            bank_age[rs_tag[ch]] <= rs_next_age(live, bank_age);

        if (!stall_dp) begin
          wr0 = !src_en[0] && store_en[0] && valid_dp[0] && path_ok(0);
          wr1 = !src_en[1] && store_en[1] && valid_dp[1] && path_ok(1);

          free_m = '0;
          for (int i = 0; i < RS_WAYS; i++)
            free_m[i] = !bank_valid[i] || way_kill(i);
          free0    = rs_pe_lo(free_m);
          free1    = rs_pe_lo2(free_m);
          next_age = rs_next_age(~free_m, bank_age);

          raw_rs1 = rs_disp_raw_rs1(
            wr0, opcode_dp[0], funct3_dp[0], rob_tag_dp[0], ps1_tag_dp[1]);
          raw_rs2 = rs_disp_raw_rs2(
            wr0, opcode_dp[0], funct3_dp[0], rob_tag_dp[0], ps2_tag_dp[1]);

          if (wr0) begin
            write_way(free0, 0, next_age, 1'b0, 1'b0);
            next_age = next_age + rs_age_t'(1);
          end
          if (wr1)
            write_way(wr0 ? free1 : free0, 1, next_age, raw_rs1, raw_rs2);
        end
      end
    end
  end

endmodule
