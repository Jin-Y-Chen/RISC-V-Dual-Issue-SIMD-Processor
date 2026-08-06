`timescale 1ns / 1ps

// Reservation station — owns bank + select (no bank ports).
// Combo: readiness → 4→2 age pick → issue mux; ↓clk applies clear/age/store.
import rv_dis_pkg::*;
import rs_pkg::*;

module reservation_station (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        path_en,
  input  logic        path_sel,

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

  output logic        stall_dp,

  output logic        iss_valid    [2],
  output logic        iss_lane_sel [2],
  output opcode_t     iss_opcode   [2],
  output funct3_t     iss_funct3   [2],
  output funct7_t     iss_funct7   [2],
  output prf_addr_t   iss_prd      [2],
  output word_t       iss_imm      [2],
  output word_t       iss_pc       [2],
  output prf_addr_t   ps1_prf      [2],
  output prf_addr_t   ps2_prf      [2]
);

  // ---- bank (internal) ----
  logic      bank_valid    [RS_WAYS];
  rs_way_t   bank_rs_tag   [RS_WAYS];
  rs_age_t   bank_age      [RS_WAYS];
  logic      bank_lane_sel [RS_WAYS];
  logic      bank_spec     [RS_WAYS];
  logic      bank_rs1_rdy  [RS_WAYS];
  logic      bank_rs2_rdy  [RS_WAYS];
  opcode_t   bank_opcode   [RS_WAYS];
  funct3_t   bank_funct3   [RS_WAYS];
  funct7_t   bank_funct7   [RS_WAYS];
  prf_addr_t bank_ps1      [RS_WAYS];
  prf_addr_t bank_ps2      [RS_WAYS];
  prf_addr_t bank_prd      [RS_WAYS];
  word_t     bank_imm      [RS_WAYS];
  word_t     bank_pc       [RS_WAYS];

  // ---- select → ↓clk controls (internal) ----
  logic    src_en   [2];
  logic    store_en [2];
  rs_way_t rs_tag   [2];

  logic     path_ok_d [2];
  rs_mask_t bank_valid_m;
  rs_mask_t bank_ready;

  logic     rs_cand_v   [2];
  rs_way_t  rs_cand_w   [2];
  rs_age_t  rs_cand_age [2];

  logic [3:0] cand_v;
  rs_age_t    cand_age [4];

  logic     iss_fire [2];
  logic     iss_src  [2];
  rs_way_t  iss_tag  [2];

  logic bank_rs1_rdy_w [RS_WAYS];
  logic bank_rs2_rdy_w [RS_WAYS];

  // Wakeup view (combo).
  always_comb begin
    for (int i = 0; i < RS_WAYS; i++) begin
      bank_rs1_rdy_w[i] = rs_wake_bit(
        bank_valid[i], bank_rs1_rdy[i], bank_ps1[i], wb_en, rob_tag_wb);
      bank_rs2_rdy_w[i] = rs_wake_bit(
        bank_valid[i], bank_rs2_rdy[i], bank_ps2[i], wb_en, rob_tag_wb);
    end
  end

  // ---- readiness + 4-candidate pool ----
  always_comb begin
    logic     raw_rs1, raw_rs2;
    logic     byp_ready [2];
    rs_mask_t m;
    rs_age_t  rn_base;

    path_ok_d[0] = rs_path_ok(path_en, path_use_dp[0], path_sel);
    path_ok_d[1] = rs_path_ok(path_en, path_use_dp[1], path_sel);

    raw_rs1 = rs_disp_raw_rs1(
      valid_dp[0] && path_ok_d[0], opcode_dp[0], funct3_dp[0], rob_tag_dp[0],
      ps1_tag_dp[1]);
    raw_rs2 = rs_disp_raw_rs2(
      valid_dp[0] && path_ok_d[0], opcode_dp[0], funct3_dp[0], rob_tag_dp[0],
      ps2_tag_dp[1]);

    byp_ready[0] = path_ok_d[0] && rs_disp_ready(
      valid_dp[0], ps1_tag_dp[0], ps2_tag_dp[0],
      bank_valid, bank_prd, wb_en, rob_tag_wb, 1'b0, 1'b0);
    byp_ready[1] = path_ok_d[1] && rs_disp_ready(
      valid_dp[1], ps1_tag_dp[1], ps2_tag_dp[1],
      bank_valid, bank_prd, wb_en, rob_tag_wb, raw_rs1, raw_rs2);

    for (int i = 0; i < RS_WAYS; i++) begin
      bank_valid_m[i] = bank_valid[i] &&
                        rs_path_ok(path_en, bank_spec[i], path_sel);
      bank_ready[i]   = rs_path_ok(path_en, bank_spec[i], path_sel) &&
                        rs_calc_issue_ready(
                          bank_valid[i], bank_ps1[i], bank_ps2[i],
                          bank_rs1_rdy[i], bank_rs2_rdy[i],
                          wb_en, rob_tag_wb);
    end

    m = (enable && !flush) ? bank_ready : '0;
    for (int i = 0; i < 2; i++) begin
      rs_cand_v[i]   = 1'b0;
      rs_cand_w[i]   = '0;
      rs_cand_age[i] = '0;
    end
    for (int i = 0; i < 2; i++) begin
      if (|m) begin
        rs_cand_w[i]   = rs_pick_oldest(m, bank_age);
        rs_cand_v[i]   = 1'b1;
        rs_cand_age[i] = bank_age[rs_cand_w[i]];
        m = m & ~(rs_mask_t'(1) << rs_cand_w[i]);
      end
    end

    rn_base = rs_next_age(bank_valid_m, bank_age);
    cand_v  = {enable && !flush && byp_ready[1],
               enable && !flush && byp_ready[0],
               rs_cand_v[1],
               rs_cand_v[0]};
    cand_age[0] = rs_cand_age[0];
    cand_age[1] = rs_cand_age[1];
    cand_age[2] = rn_base;
    cand_age[3] = rn_base + rs_age_t'(1);
  end

  // ---- 4→2 pick + RS control packing ----
  always_comb begin
    logic [3:0] m, pk;
    int         i0, av, need, n_occ;
    logic       st [2];

    av = rs_free_ways(bank_valid_m, bank_prd, wb_en, rob_tag_wb);

    pk = '0;
    m  = cand_v;
    for (int k = 0; k < 2; k++) begin
      if (|m) begin
        i0     = rs_pick_oldest4(m, cand_age);
        pk[i0] = 1'b1;
        m[i0]  = 1'b0;
      end
    end

    need = (valid_dp[0] && path_ok_d[0] && !pk[C_BY0])
         + (valid_dp[1] && path_ok_d[1] && !pk[C_BY1]);
    if (need > av) begin
      pk[C_BY0] = 1'b0;
      pk[C_BY1] = 1'b0;
      pk[C_RS0] = cand_v[C_RS0];
      pk[C_RS1] = cand_v[C_RS1];
      need = (valid_dp[0] && path_ok_d[0]) + (valid_dp[1] && path_ok_d[1]);
    end
    stall_dp = !flush && (need > av);

    for (int guard = 0; guard < 2; guard++) begin
      st[0] = enable && !flush && !stall_dp
           && valid_dp[0] && path_ok_d[0] && !pk[C_BY0];
      st[1] = enable && !flush && !stall_dp
           && valid_dp[1] && path_ok_d[1] && !pk[C_BY1];
      n_occ = pk[C_RS0] + pk[C_RS1] + st[0] + st[1];
      if (n_occ <= 2)
        break;
      if (pk[C_RS0] && pk[C_RS1])
        pk[(rs_cand_age[1] >= rs_cand_age[0]) ? C_RS1 : C_RS0] = 1'b0;
      else
        pk[pk[C_RS1] ? C_RS1 : C_RS0] = 1'b0;
      if (!pk[C_BY0] && cand_v[C_BY0] &&
          (pk[C_RS0] + pk[C_RS1] + pk[C_BY0] + pk[C_BY1] < 2))
        pk[C_BY0] = 1'b1;
      if (!pk[C_BY1] && cand_v[C_BY1] &&
          (pk[C_RS0] + pk[C_RS1] + pk[C_BY0] + pk[C_BY1] < 2))
        pk[C_BY1] = 1'b1;
    end
    st[0] = enable && !flush && !stall_dp
         && valid_dp[0] && path_ok_d[0] && !pk[C_BY0];
    st[1] = enable && !flush && !stall_dp
         && valid_dp[1] && path_ok_d[1] && !pk[C_BY1];

    src_en[0]   = 1'b0;
    src_en[1]   = 1'b0;
    store_en[0] = st[0];
    store_en[1] = st[1];
    rs_tag[0]   = '0;
    rs_tag[1]   = '0;

    for (int r = 0; r < 2; r++) begin
      if (pk[r]) begin
        if (!(r == 0 ? st[0] : (src_en[0] || store_en[0]))) begin
          src_en[0]   = 1'b1;
          store_en[0] = 1'b0;
          rs_tag[0]   = bank_rs_tag[rs_cand_w[r]];
        end else begin
          src_en[1]   = 1'b1;
          store_en[1] = 1'b0;
          rs_tag[1]   = bank_rs_tag[rs_cand_w[r]];
        end
      end
    end
    for (int r = 0; r < 2; r++) begin
      if (rs_cand_v[r] && !pk[r]) begin
        if (!src_en[0] && !store_en[0]) begin
          src_en[0] = 1'b1; store_en[0] = 1'b1;
          rs_tag[0] = bank_rs_tag[rs_cand_w[r]];
        end else if (!src_en[1] && !store_en[1]) begin
          src_en[1] = 1'b1; store_en[1] = 1'b1;
          rs_tag[1] = bank_rs_tag[rs_cand_w[r]];
        end
      end
    end

    for (int i = 0; i < 2; i++) begin
      iss_fire[i] = 1'b0;
      iss_src[i]  = 1'b1;
      iss_tag[i]  = '0;
    end
    m = pk;
    for (int slot = 0; slot < 2; slot++) begin
      if (|m) begin
        i0 = rs_pick_oldest4(m, cand_age);
        iss_fire[slot] = 1'b1;
        if (i0 <= C_RS1) begin
          iss_src[slot] = 1'b0;
          iss_tag[slot] = bank_rs_tag[rs_cand_w[i0]];
        end else begin
          iss_src[slot] = 1'b1;
          iss_tag[slot] = rs_way_t'(i0 - C_BY0);
        end
        m[i0] = 1'b0;
      end
    end
  end

  // ---- issue mux ----
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      int d;
      d = int'(iss_tag[i][0]);
      iss_valid[i] = iss_fire[i];
      if (iss_fire[i] && iss_src[i]) begin
        iss_lane_sel[i] = lane_sel_dp[d];
        iss_opcode[i]   = opcode_dp[d];
        iss_funct3[i]   = funct3_dp[d];
        iss_funct7[i]   = funct7_dp[d];
        iss_prd[i]      = rob_tag_dp[d];
        iss_imm[i]      = imm_dp[d];
        iss_pc[i]       = pc_dp[d];
        ps1_prf[i]      = ps1_tag_dp[d];
        ps2_prf[i]      = ps2_tag_dp[d];
      end else if (iss_fire[i]) begin
        iss_lane_sel[i] = bank_lane_sel[iss_tag[i]];
        iss_opcode[i]   = bank_opcode[iss_tag[i]];
        iss_funct3[i]   = bank_funct3[iss_tag[i]];
        iss_funct7[i]   = bank_funct7[iss_tag[i]];
        iss_prd[i]      = bank_prd[iss_tag[i]];
        iss_imm[i]      = bank_imm[iss_tag[i]];
        iss_pc[i]       = bank_pc[iss_tag[i]];
        ps1_prf[i]      = bank_ps1[iss_tag[i]];
        ps2_prf[i]      = bank_ps2[iss_tag[i]];
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

  // ---- ↓clk bank update ----
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
      for (int i = 0; i < RS_WAYS; i++) begin
        if (rs_way_kill(i, enable, path_en, path_sel,
                        bank_valid[i], bank_spec[i], bank_prd[i],
                        wb_en, rob_tag_wb, src_en, store_en, rs_tag))
          clear_way(i);
        else begin
          bank_rs1_rdy[i] <= bank_rs1_rdy_w[i];
          bank_rs2_rdy[i] <= bank_rs2_rdy_w[i];
        end
      end

      if (enable) begin
        for (int i = 0; i < RS_WAYS; i++)
          live[i] = bank_valid[i];
        for (int ch = 0; ch < 2; ch++)
          if (src_en[ch] && store_en[ch])
            bank_age[rs_tag[ch]] <= rs_next_age(live, bank_age);

        if (!stall_dp) begin
          wr0 = !src_en[0] && store_en[0] && valid_dp[0] &&
                rs_path_ok(path_en, path_use_dp[0], path_sel);
          wr1 = !src_en[1] && store_en[1] && valid_dp[1] &&
                rs_path_ok(path_en, path_use_dp[1], path_sel);

          free_m = '0;
          for (int i = 0; i < RS_WAYS; i++)
            free_m[i] = !bank_valid[i] ||
                        rs_way_kill(i, enable, path_en, path_sel,
                                    bank_valid[i], bank_spec[i], bank_prd[i],
                                    wb_en, rob_tag_wb, src_en, store_en, rs_tag);
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
