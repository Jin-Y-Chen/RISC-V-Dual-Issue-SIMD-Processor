`timescale 1ns / 1ps

// Selector pick — 4→2 age arb, stall, RS control packing, issue fire tags.
import rv_dis_pkg::*;
import rs_pkg::*;

module sel_pick (
  input  logic        enable,
  input  logic        flush,

  input  logic        path_ok_d [2],
  input  rs_mask_t    bank_valid_m,
  input  prf_addr_t   bank_prd      [RS_WAYS],
  input  rs_way_t     bank_rs_tag   [RS_WAYS],

  input  logic        wb_en      [2],
  input  prf_addr_t   rob_tag_wb [2],

  input  logic        valid_dp [2],

  input  logic        rs_cand_v   [2],
  input  rs_way_t     rs_cand_w   [2],
  input  rs_age_t     rs_cand_age [2],

  input  logic [3:0]  cand_v,
  input  rs_age_t     cand_age [4],

  output logic        src_en   [2],
  output rs_way_t     rs_tag   [2],
  output logic        store_en [2],
  output logic        stall_dp,

  output logic        iss_fire [2],
  output logic        iss_src  [2],
  output rs_way_t     iss_tag  [2]
);

  localparam int C_RS0 = 0;
  localparam int C_RS1 = 1;
  localparam int C_BY0 = 2;
  localparam int C_BY1 = 3;

  always_comb begin
    logic [3:0] m, pk;
    int         i0, av, need, n_occ, u, n_wb;
    logic       st [2];

    // Occupancy (+ same-cycle WB frees).
    u = 0; n_wb = 0;
    for (int i = 0; i < RS_WAYS; i++) begin
      u += bank_valid_m[i];
      if (bank_valid_m[i] && rs_wb_hit(bank_prd[i], wb_en, rob_tag_wb))
        n_wb++;
    end
    av = RS_WAYS - u + n_wb;

    // Age-pick up to 2 of 4 candidates.
    pk = '0;
    m  = cand_v;
    for (int k = 0; k < 2; k++) begin
      if (|m) begin
        i0    = rs_pick_oldest4(m, cand_age);
        pk[i0] = 1'b1;
        m[i0]  = 1'b0;
      end
    end

    // Stall if unpicked renames need more free ways than available.
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

    // Fit clears + stores into 2 control channels (drop youngest RS if needed).
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
      if (!pk[C_BY0] && cand_v[C_BY0] && (pk[C_RS0]+pk[C_RS1]+pk[C_BY0]+pk[C_BY1] < 2))
        pk[C_BY0] = 1'b1;
      if (!pk[C_BY1] && cand_v[C_BY1] && (pk[C_RS0]+pk[C_RS1]+pk[C_BY0]+pk[C_BY1] < 2))
        pk[C_BY1] = 1'b1;
    end
    st[0] = enable && !flush && !stall_dp
         && valid_dp[0] && path_ok_d[0] && !pk[C_BY0];
    st[1] = enable && !flush && !stall_dp
         && valid_dp[1] && path_ok_d[1] && !pk[C_BY1];

    // Pack: rename stores keep lane index; RS clear/age use free channels.
    src_en[0]   = 1'b0;
    src_en[1]   = 1'b0;
    store_en[0] = st[0];
    store_en[1] = st[1];
    rs_tag[0]   = '0;
    rs_tag[1]   = '0;

    for (int r = 0; r < 2; r++) begin
      if (pk[r]) begin
        // Prefer ch not holding a rename store.
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

    // Issue ports in age order among picked cands.
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

endmodule
