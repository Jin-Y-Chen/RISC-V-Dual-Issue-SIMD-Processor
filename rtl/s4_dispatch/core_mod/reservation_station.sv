`timescale 1ns / 1ps

// Central renamed reservation station. It accepts a dual dispatch bundle,
// tracks physical-register readiness, wakes operands from writeback, and issues
// the two oldest ready instructions each cycle.
import rv_dis_pkg::*;

module reservation_station #(
  parameter int DEPTH = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // Renamed dispatch bundle.
  input  logic        i0_valid_dp,
  input  logic        i0_lane_sel_dp,
  input  logic        i0_reg_write_dp,
  input  logic        i0_rs1_use_dp,
  input  logic        i0_rs2_use_dp,
  input  opcode_t     i0_opcode_dp,
  input  funct3_t     i0_funct3_dp,
  input  funct7_t     i0_funct7_dp,
  input  prf_addr_t   i0_ps1_dp,
  input  prf_addr_t   i0_ps2_dp,
  input  prf_addr_t   i0_prd_dp,
  input  prf_addr_t    i0_rob_idx_dp,
  input  word_t       i0_imm_dp,
  input  word_t       i0_pc_dp,
  input  word_t       i0_ps1_data_dp,
  input  word_t       i0_ps2_data_dp,

  input  logic        i1_valid_dp,
  input  logic        i1_lane_sel_dp,
  input  logic        i1_reg_write_dp,
  input  logic        i1_rs1_use_dp,
  input  logic        i1_rs2_use_dp,
  input  opcode_t     i1_opcode_dp,
  input  funct3_t     i1_funct3_dp,
  input  funct7_t     i1_funct7_dp,
  input  prf_addr_t   i1_ps1_dp,
  input  prf_addr_t   i1_ps2_dp,
  input  prf_addr_t   i1_prd_dp,
  input  prf_addr_t    i1_rob_idx_dp,
  input  word_t       i1_imm_dp,
  input  word_t       i1_pc_dp,
  input  word_t       i1_ps1_data_dp,
  input  word_t       i1_ps2_data_dp,

  // Physical-register writeback broadcasts.
  input  logic        wb0_en,
  input  prf_addr_t   wb0_prd,
  input  word_t       wb0_data,
  input  logic        wb1_en,
  input  prf_addr_t   wb1_prd,
  input  word_t       wb1_data,

  // Independent execution-slot backpressure.
  input  logic        issue0_ready,
  input  logic        issue1_ready,
  output logic        stall_dp,
  output logic [$clog2(DEPTH+1)-1:0] occupancy,

  output logic        i0_valid_ex,
  output logic        i0_lane_sel_ex,
  output logic        i0_reg_write_ex,
  output opcode_t     i0_opcode_ex,
  output funct3_t     i0_funct3_ex,
  output funct7_t     i0_funct7_ex,
  output prf_addr_t   i0_ps1_ex,
  output prf_addr_t   i0_ps2_ex,
  output prf_addr_t   i0_prd_ex,
  output prf_addr_t    i0_rob_idx_ex,
  output word_t       i0_imm_ex,
  output word_t       i0_pc_ex,
  output word_t       i0_rs1_data_ex,
  output word_t       i0_rs2_data_ex,

  output logic        i1_valid_ex,
  output logic        i1_lane_sel_ex,
  output logic        i1_reg_write_ex,
  output opcode_t     i1_opcode_ex,
  output funct3_t     i1_funct3_ex,
  output funct7_t     i1_funct7_ex,
  output prf_addr_t   i1_ps1_ex,
  output prf_addr_t   i1_ps2_ex,
  output prf_addr_t   i1_prd_ex,
  output prf_addr_t    i1_rob_idx_ex,
  output word_t       i1_imm_ex,
  output word_t       i1_pc_ex,
  output word_t       i1_rs1_data_ex,
  output word_t       i1_rs2_data_ex
);

  typedef struct packed {
    logic       valid;
    logic [31:0] age;
    logic       lane_sel;
    logic       reg_write;
    logic       rs1_use;
    logic       rs2_use;
    logic       rs1_ready;
    logic       rs2_ready;
    opcode_t    opcode;
    funct3_t    funct3;
    funct7_t    funct7;
    prf_addr_t  ps1;
    prf_addr_t  ps2;
    prf_addr_t  prd;
    prf_addr_t   rob_idx;
    word_t      imm;
    word_t      pc;
    word_t      rs1_data;
    word_t      rs2_data;
  } rs_entry_t;

  rs_entry_t entries_q [DEPTH];
  rs_entry_t entries_n [DEPTH];
  logic [NUM_PRF-1:0] prf_ready_q, prf_ready_n;
  logic [31:0] age_q, age_n;

  integer sel0, sel1;
  logic [31:0] sel0_age, sel1_age;
  logic issue0_fire, issue1_fire;

  function automatic logic wb_hit(input prf_addr_t tag);
    return (wb0_en && (wb0_prd == tag)) ||
           (wb1_en && (wb1_prd == tag));
  endfunction

  function automatic word_t forwarded_data(
    input prf_addr_t tag,
    input word_t     stored
  );
    if (wb1_en && (wb1_prd == tag))
      return wb1_data;
    if (wb0_en && (wb0_prd == tag))
      return wb0_data;
    return stored;
  endfunction

  function automatic logic entry_ready(input rs_entry_t entry);
    logic src1_ready, src2_ready;
    src1_ready = !entry.rs1_use || entry.rs1_ready || wb_hit(entry.ps1);
    src2_ready = !entry.rs2_use || entry.rs2_ready || wb_hit(entry.ps2);
    return entry.valid && src1_ready && src2_ready;
  endfunction

  // Oldest-ready selection. Physical tags remove WAR/WAW hazards; only source
  // readiness constrains out-of-order issue.
  always_comb begin
    sel0 = -1;
    sel1 = -1;
    sel0_age = '1;
    sel1_age = '1;

    if (enable && !flush) begin
      for (int i = 0; i < DEPTH; i++) begin
        if (entry_ready(entries_q[i]) &&
            ((sel0 < 0) || (entries_q[i].age < sel0_age))) begin
          sel0 = i;
          sel0_age = entries_q[i].age;
        end
      end
      for (int i = 0; i < DEPTH; i++) begin
        if ((i != sel0) && entry_ready(entries_q[i]) &&
            ((sel1 < 0) || (entries_q[i].age < sel1_age))) begin
          sel1 = i;
          sel1_age = entries_q[i].age;
        end
      end
    end
  end

  always_comb begin
    i0_valid_ex     = 1'b0;
    i0_lane_sel_ex  = 1'b0;
    i0_reg_write_ex = 1'b0;
    i0_opcode_ex    = '0;
    i0_funct3_ex    = '0;
    i0_funct7_ex    = '0;
    i0_ps1_ex       = '0;
    i0_ps2_ex       = '0;
    i0_prd_ex       = '0;
    i0_rob_idx_ex   = '0;
    i0_imm_ex       = '0;
    i0_pc_ex        = '0;
    i0_rs1_data_ex  = '0;
    i0_rs2_data_ex  = '0;

    i1_valid_ex     = 1'b0;
    i1_lane_sel_ex  = 1'b0;
    i1_reg_write_ex = 1'b0;
    i1_opcode_ex    = '0;
    i1_funct3_ex    = '0;
    i1_funct7_ex    = '0;
    i1_ps1_ex       = '0;
    i1_ps2_ex       = '0;
    i1_prd_ex       = '0;
    i1_rob_idx_ex   = '0;
    i1_imm_ex       = '0;
    i1_pc_ex        = '0;
    i1_rs1_data_ex  = '0;
    i1_rs2_data_ex  = '0;

    if (sel0 >= 0) begin
      i0_valid_ex     = 1'b1;
      i0_lane_sel_ex  = entries_q[sel0].lane_sel;
      i0_reg_write_ex = entries_q[sel0].reg_write;
      i0_opcode_ex    = entries_q[sel0].opcode;
      i0_funct3_ex    = entries_q[sel0].funct3;
      i0_funct7_ex    = entries_q[sel0].funct7;
      i0_ps1_ex       = entries_q[sel0].ps1;
      i0_ps2_ex       = entries_q[sel0].ps2;
      i0_prd_ex       = entries_q[sel0].prd;
      i0_rob_idx_ex   = entries_q[sel0].rob_idx;
      i0_imm_ex       = entries_q[sel0].imm;
      i0_pc_ex        = entries_q[sel0].pc;
      i0_rs1_data_ex  = forwarded_data(entries_q[sel0].ps1,
                                       entries_q[sel0].rs1_data);
      i0_rs2_data_ex  = forwarded_data(entries_q[sel0].ps2,
                                       entries_q[sel0].rs2_data);
    end

    if (sel1 >= 0) begin
      i1_valid_ex     = 1'b1;
      i1_lane_sel_ex  = entries_q[sel1].lane_sel;
      i1_reg_write_ex = entries_q[sel1].reg_write;
      i1_opcode_ex    = entries_q[sel1].opcode;
      i1_funct3_ex    = entries_q[sel1].funct3;
      i1_funct7_ex    = entries_q[sel1].funct7;
      i1_ps1_ex       = entries_q[sel1].ps1;
      i1_ps2_ex       = entries_q[sel1].ps2;
      i1_prd_ex       = entries_q[sel1].prd;
      i1_rob_idx_ex   = entries_q[sel1].rob_idx;
      i1_imm_ex       = entries_q[sel1].imm;
      i1_pc_ex        = entries_q[sel1].pc;
      i1_rs1_data_ex  = forwarded_data(entries_q[sel1].ps1,
                                       entries_q[sel1].rs1_data);
      i1_rs2_data_ex  = forwarded_data(entries_q[sel1].ps2,
                                       entries_q[sel1].rs2_data);
    end
  end

  assign issue0_fire = i0_valid_ex && issue0_ready;
  assign issue1_fire = i1_valid_ex && issue1_ready;

  always_comb begin
    int used, incoming, available;
    used = 0;
    for (int i = 0; i < DEPTH; i++)
      used += entries_q[i].valid;

    incoming = i0_valid_dp + i1_valid_dp;
    available = DEPTH - used + issue0_fire + issue1_fire;
    occupancy = used[$clog2(DEPTH+1)-1:0];
    stall_dp = !flush && (incoming > available);
  end

  always_comb begin
    int free0, free1, i1_slot;
    logic i1_dep_rs1, i1_dep_rs2;

    entries_n = entries_q;
    prf_ready_n = prf_ready_q;
    age_n = age_q;

    // Wake waiting operands and make completed physical registers reusable by
    // subsequent dependency checks.
    for (int i = 0; i < DEPTH; i++) begin
      if (entries_n[i].valid && !entries_n[i].rs1_ready &&
          wb_hit(entries_n[i].ps1)) begin
        entries_n[i].rs1_ready = 1'b1;
        entries_n[i].rs1_data = forwarded_data(entries_n[i].ps1,
                                               entries_n[i].rs1_data);
      end
      if (entries_n[i].valid && !entries_n[i].rs2_ready &&
          wb_hit(entries_n[i].ps2)) begin
        entries_n[i].rs2_ready = 1'b1;
        entries_n[i].rs2_data = forwarded_data(entries_n[i].ps2,
                                               entries_n[i].rs2_data);
      end
    end
    if (wb0_en) prf_ready_n[wb0_prd] = 1'b1;
    if (wb1_en) prf_ready_n[wb1_prd] = 1'b1;

    if (issue0_fire) entries_n[sel0] = '0;
    if (issue1_fire) entries_n[sel1] = '0;

    free0 = -1;
    free1 = -1;
    for (int i = 0; i < DEPTH; i++) begin
      if (!entries_n[i].valid) begin
        if (free0 < 0)
          free0 = i;
        else if (free1 < 0)
          free1 = i;
      end
    end

    if (enable && !flush && !stall_dp) begin
      if (i0_valid_dp) begin
        entries_n[free0].valid = 1'b1;
        entries_n[free0].age = age_n;
        entries_n[free0].lane_sel = i0_lane_sel_dp;
        entries_n[free0].reg_write = i0_reg_write_dp;
        entries_n[free0].rs1_use = i0_rs1_use_dp;
        entries_n[free0].rs2_use = i0_rs2_use_dp;
        entries_n[free0].rs1_ready = !i0_rs1_use_dp ||
                                     prf_ready_n[i0_ps1_dp] ||
                                     wb_hit(i0_ps1_dp);
        entries_n[free0].rs2_ready = !i0_rs2_use_dp ||
                                     prf_ready_n[i0_ps2_dp] ||
                                     wb_hit(i0_ps2_dp);
        entries_n[free0].opcode = i0_opcode_dp;
        entries_n[free0].funct3 = i0_funct3_dp;
        entries_n[free0].funct7 = i0_funct7_dp;
        entries_n[free0].ps1 = i0_ps1_dp;
        entries_n[free0].ps2 = i0_ps2_dp;
        entries_n[free0].prd = i0_prd_dp;
        entries_n[free0].rob_idx = i0_rob_idx_dp;
        entries_n[free0].imm = i0_imm_dp;
        entries_n[free0].pc = i0_pc_dp;
        entries_n[free0].rs1_data = forwarded_data(i0_ps1_dp,
                                                   i0_ps1_data_dp);
        entries_n[free0].rs2_data = forwarded_data(i0_ps2_dp,
                                                   i0_ps2_data_dp);
        age_n = age_n + 1'b1;
      end

      i1_slot = i0_valid_dp ? free1 : free0;
      if (i1_valid_dp) begin
        i1_dep_rs1 = i0_valid_dp && i0_reg_write_dp &&
                     (i0_prd_dp != '0) && (i1_ps1_dp == i0_prd_dp);
        i1_dep_rs2 = i0_valid_dp && i0_reg_write_dp &&
                     (i0_prd_dp != '0) && (i1_ps2_dp == i0_prd_dp);

        entries_n[i1_slot].valid = 1'b1;
        entries_n[i1_slot].age = age_n;
        entries_n[i1_slot].lane_sel = i1_lane_sel_dp;
        entries_n[i1_slot].reg_write = i1_reg_write_dp;
        entries_n[i1_slot].rs1_use = i1_rs1_use_dp;
        entries_n[i1_slot].rs2_use = i1_rs2_use_dp;
        entries_n[i1_slot].rs1_ready = !i1_rs1_use_dp ||
                                       (!i1_dep_rs1 &&
                                        (prf_ready_n[i1_ps1_dp] ||
                                         wb_hit(i1_ps1_dp)));
        entries_n[i1_slot].rs2_ready = !i1_rs2_use_dp ||
                                       (!i1_dep_rs2 &&
                                        (prf_ready_n[i1_ps2_dp] ||
                                         wb_hit(i1_ps2_dp)));
        entries_n[i1_slot].opcode = i1_opcode_dp;
        entries_n[i1_slot].funct3 = i1_funct3_dp;
        entries_n[i1_slot].funct7 = i1_funct7_dp;
        entries_n[i1_slot].ps1 = i1_ps1_dp;
        entries_n[i1_slot].ps2 = i1_ps2_dp;
        entries_n[i1_slot].prd = i1_prd_dp;
        entries_n[i1_slot].rob_idx = i1_rob_idx_dp;
        entries_n[i1_slot].imm = i1_imm_dp;
        entries_n[i1_slot].pc = i1_pc_dp;
        entries_n[i1_slot].rs1_data = forwarded_data(i1_ps1_dp,
                                                     i1_ps1_data_dp);
        entries_n[i1_slot].rs2_data = forwarded_data(i1_ps2_dp,
                                                     i1_ps2_data_dp);
        age_n = age_n + 1'b1;
      end

      // Newly allocated destinations become unavailable until writeback.
      if (i0_valid_dp && i0_reg_write_dp && (i0_prd_dp != '0))
        prf_ready_n[i0_prd_dp] = 1'b0;
      if (i1_valid_dp && i1_reg_write_dp && (i1_prd_dp != '0))
        prf_ready_n[i1_prd_dp] = 1'b0;
    end

    prf_ready_n[0] = 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      for (int i = 0; i < DEPTH; i++)
        entries_q[i] <= '0;
      prf_ready_q <= '1;
      age_q <= '0;
    end else begin
      entries_q <= entries_n;
      prf_ready_q <= prf_ready_n;
      age_q <= age_n;
    end
  end

endmodule
