`timescale 1ns / 1ps

// Reservation stations — four renamed lane queues (ev0, ev1, od0, od1).
// Dispatch routes by lane_sel; each enable allocates an rs_entry_t tagged by renamed_tag.
// Issue oldest ready entry per queue to the matching execute lane copy.
module reservation_station
  import rv_dis_pkg::*;
  import rob_rename_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // issue-slot tags — pass through from dispatch (program order)
  input  logic        i0_reg_write_disp,
  input  logic        i1_reg_write_disp,
  input  word_t       i0_pc_disp,
  input  word_t       i1_pc_disp,
  output logic        i0_reg_write_ex,
  output logic        i1_reg_write_ex,
  output word_t       i0_pc_ex,
  output word_t       i1_pc_ex,

  // dispatch in — renamed EX packets (from id_ex_dispatch)
  input  logic        ev0_enable_disp,
  input  opcode_t     ev0_opcode_disp,
  input  funct3_t     ev0_funct3_disp,
  input  funct7_t     ev0_funct7_disp,
  input  gpr_addr_t   ev0_rd_disp,
  input  gpr_addr_t   ev0_rs1_addr_disp,
  input  gpr_addr_t   ev0_rs2_addr_disp,
  input  word_t       ev0_imm_disp,
  input  word_t       ev0_rs1_data_disp,
  input  word_t       ev0_rs2_data_disp,
  input  word_t       ev0_pc_disp,

  input  logic        ev1_enable_disp,
  input  opcode_t     ev1_opcode_disp,
  input  funct3_t     ev1_funct3_disp,
  input  funct7_t     ev1_funct7_disp,
  input  gpr_addr_t   ev1_rd_disp,
  input  gpr_addr_t   ev1_rs1_addr_disp,
  input  gpr_addr_t   ev1_rs2_addr_disp,
  input  word_t       ev1_imm_disp,
  input  word_t       ev1_rs1_data_disp,
  input  word_t       ev1_rs2_data_disp,
  input  word_t       ev1_pc_disp,

  input  logic        od0_enable_disp,
  input  opcode_t     od0_opcode_disp,
  input  funct3_t     od0_funct3_disp,
  input  gpr_addr_t   od0_rd_disp,
  input  gpr_addr_t   od0_rs1_addr_disp,
  input  gpr_addr_t   od0_rs2_addr_disp,
  input  word_t       od0_imm_disp,
  input  word_t       od0_rs1_data_disp,
  input  word_t       od0_rs2_data_disp,
  input  word_t       od0_pc_disp,

  input  logic        od1_enable_disp,
  input  opcode_t     od1_opcode_disp,
  input  funct3_t     od1_funct3_disp,
  input  gpr_addr_t   od1_rd_disp,
  input  gpr_addr_t   od1_rs1_addr_disp,
  input  gpr_addr_t   od1_rs2_addr_disp,
  input  word_t       od1_imm_disp,
  input  word_t       od1_rs1_data_disp,
  input  word_t       od1_rs2_data_disp,
  input  word_t       od1_pc_disp,

  // writeback — operand bypass at issue
  input  logic        wb0_reg_write,
  input  gpr_addr_t   wb0_rd_addr,
  input  word_t       wb0_data,
  input  word_t       wb0_pc,
  input  logic        wb1_reg_write,
  input  gpr_addr_t   wb1_rd_addr,
  input  word_t       wb1_data,
  input  word_t       wb1_pc,

  // execute out — issued renamed packets
  output logic        ev0_enable_ex,
  output opcode_t     ev0_opcode_ex,
  output funct3_t     ev0_funct3_ex,
  output funct7_t     ev0_funct7_ex,
  output gpr_addr_t   ev0_rd_ex,
  output gpr_addr_t   ev0_rs1_addr_ex,
  output gpr_addr_t   ev0_rs2_addr_ex,
  output word_t       ev0_imm_ex,
  output word_t       ev0_rs1_data_ex,
  output word_t       ev0_rs2_data_ex,
  output word_t       ev0_pc_ex,

  output logic        ev1_enable_ex,
  output opcode_t     ev1_opcode_ex,
  output funct3_t     ev1_funct3_ex,
  output funct7_t     ev1_funct7_ex,
  output gpr_addr_t   ev1_rd_ex,
  output gpr_addr_t   ev1_rs1_addr_ex,
  output gpr_addr_t   ev1_rs2_addr_ex,
  output word_t       ev1_imm_ex,
  output word_t       ev1_rs1_data_ex,
  output word_t       ev1_rs2_data_ex,
  output word_t       ev1_pc_ex,

  output logic        od0_enable_ex,
  output opcode_t     od0_opcode_ex,
  output funct3_t     od0_funct3_ex,
  output gpr_addr_t   od0_rd_ex,
  output gpr_addr_t   od0_rs1_addr_ex,
  output gpr_addr_t   od0_rs2_addr_ex,
  output word_t       od0_imm_ex,
  output word_t       od0_rs1_data_ex,
  output word_t       od0_rs2_data_ex,
  output word_t       od0_pc_ex,

  output logic        od1_enable_ex,
  output opcode_t     od1_opcode_ex,
  output funct3_t     od1_funct3_ex,
  output gpr_addr_t   od1_rd_ex,
  output gpr_addr_t   od1_rs1_addr_ex,
  output gpr_addr_t   od1_rs2_addr_ex,
  output word_t       od1_imm_ex,
  output word_t       od1_rs1_data_ex,
  output word_t       od1_rs2_data_ex,
  output word_t       od1_pc_ex
);

  // -----------------------------------------------------------------------
  // Per-lane RS storage (ring buffer per even/odd execute copy)
  // -----------------------------------------------------------------------
  rs_entry_t ev0_bank [0:RS_DEPTH-1];
  rs_entry_t ev1_bank [0:RS_DEPTH-1];
  rs_entry_t od0_bank [0:RS_DEPTH-1];
  rs_entry_t od1_bank [0:RS_DEPTH-1];

  rs_cnt_t ev0_wptr, ev0_rptr, ev0_count;
  rs_cnt_t ev1_wptr, ev1_rptr, ev1_count;
  rs_cnt_t od0_wptr, od0_rptr, od0_count;
  rs_cnt_t od1_wptr, od1_rptr, od1_count;

  // -----------------------------------------------------------------------
  // Dispatch -> EX_packet (renamed_tag = architectural rd until rename unit)
  // -----------------------------------------------------------------------
  function automatic EX_packet_t disp_even_packet(
    input logic      en,
    input logic      reg_write,
    input gpr_addr_t renamed_tag,
    input opcode_t   opcode,
    input funct3_t   funct3,
    input funct7_t   funct7,
    input gpr_addr_t rs1,
    input gpr_addr_t rs2,
    input word_t     imm,
    input word_t     rs1_data,
    input word_t     rs2_data,
    input word_t     pc
  );
    disp_even_packet.valid       = en;
    disp_even_packet.renamed_tag = renamed_tag;
    disp_even_packet.packet.lane_sel  = 1'b0;
    disp_even_packet.packet.reg_write = reg_write;
    disp_even_packet.packet.rs1_use   = 1'b1;
    disp_even_packet.packet.rs2_use   = 1'b1;
    disp_even_packet.packet.opcode    = opcode;
    disp_even_packet.packet.funct3    = funct3;
    disp_even_packet.packet.funct7    = funct7;
    disp_even_packet.packet.rd        = renamed_tag;
    disp_even_packet.packet.rs1       = rs1;
    disp_even_packet.packet.rs2       = rs2;
    disp_even_packet.packet.imm       = imm;
    disp_even_packet.packet.rs1_data  = rs1_data;
    disp_even_packet.packet.rs2_data  = rs2_data;
    disp_even_packet.packet.pc        = pc;
  endfunction

  function automatic EX_packet_t disp_odd_packet(
    input logic      en,
    input logic      reg_write,
    input gpr_addr_t renamed_tag,
    input opcode_t   opcode,
    input funct3_t   funct3,
    input gpr_addr_t rs1,
    input gpr_addr_t rs2,
    input word_t     imm,
    input word_t     rs1_data,
    input word_t     rs2_data,
    input word_t     pc
  );
    disp_odd_packet.valid       = en;
    disp_odd_packet.renamed_tag = renamed_tag;
    disp_odd_packet.packet.lane_sel  = 1'b1;
    disp_odd_packet.packet.reg_write = reg_write;
    disp_odd_packet.packet.rs1_use   = 1'b1;
    disp_odd_packet.packet.rs2_use   = 1'b1;
    disp_odd_packet.packet.opcode    = opcode;
    disp_odd_packet.packet.funct3    = funct3;
    disp_odd_packet.packet.funct7    = 7'd0;
    disp_odd_packet.packet.rd        = renamed_tag;
    disp_odd_packet.packet.rs1       = rs1;
    disp_odd_packet.packet.rs2       = rs2;
    disp_odd_packet.packet.imm       = imm;
    disp_odd_packet.packet.rs1_data  = rs1_data;
    disp_odd_packet.packet.rs2_data  = rs2_data;
    disp_odd_packet.packet.pc        = pc;
  endfunction

  EX_packet_t ev0_in_pkt, ev1_in_pkt, od0_in_pkt, od1_in_pkt;

  always_comb begin
    ev0_in_pkt = disp_even_packet(
      ev0_enable_disp, i0_reg_write_disp, ev0_rd_disp, ev0_opcode_disp, ev0_funct3_disp, ev0_funct7_disp,
      ev0_rs1_addr_disp, ev0_rs2_addr_disp, ev0_imm_disp,
      ev0_rs1_data_disp, ev0_rs2_data_disp, ev0_pc_disp
    );
    ev1_in_pkt = disp_even_packet(
      ev1_enable_disp, i1_reg_write_disp, ev1_rd_disp, ev1_opcode_disp, ev1_funct3_disp, ev1_funct7_disp,
      ev1_rs1_addr_disp, ev1_rs2_addr_disp, ev1_imm_disp,
      ev1_rs1_data_disp, ev1_rs2_data_disp, ev1_pc_disp
    );
    od0_in_pkt = disp_odd_packet(
      od0_enable_disp, i0_reg_write_disp, od0_rd_disp, od0_opcode_disp, od0_funct3_disp,
      od0_rs1_addr_disp, od0_rs2_addr_disp, od0_imm_disp,
      od0_rs1_data_disp, od0_rs2_data_disp, od0_pc_disp
    );
    od1_in_pkt = disp_odd_packet(
      od1_enable_disp, i1_reg_write_disp, od1_rd_disp, od1_opcode_disp, od1_funct3_disp,
      od1_rs1_addr_disp, od1_rs2_addr_disp, od1_imm_disp,
      od1_rs1_data_disp, od1_rs2_data_disp, od1_pc_disp
    );
  end

  // -----------------------------------------------------------------------
  // RAW — producer in another lane RS (same-lane younger entries excluded)
  // -----------------------------------------------------------------------
  function automatic logic rs_producer_busy(
    input gpr_addr_t  rs,
    input logic       rs_use,
    input rs_entry_t  ev0_q [RS_DEPTH],
    input rs_entry_t  ev1_q [RS_DEPTH],
    input rs_entry_t  od0_q [RS_DEPTH],
    input rs_entry_t  od1_q [RS_DEPTH],
    input int         self_lane
  );
    if (!rs_use)
      return 1'b0;
    for (int i = 0; i < RS_DEPTH; i++) begin
      if ((self_lane != 0) &&
          ev0_q[i].valid && ev0_q[i].packet.reg_write && (ev0_q[i].packet.rd == rs))
        return 1'b1;
      if ((self_lane != 1) &&
          ev1_q[i].valid && ev1_q[i].packet.reg_write && (ev1_q[i].packet.rd == rs))
        return 1'b1;
      if ((self_lane != 2) &&
          od0_q[i].valid && od0_q[i].packet.reg_write && (od0_q[i].packet.rd == rs))
        return 1'b1;
      if ((self_lane != 3) &&
          od1_q[i].valid && od1_q[i].packet.reg_write && (od1_q[i].packet.rd == rs))
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function automatic logic rs_entry_ready(
    input rs_entry_t  entry,
    input rs_entry_t  ev0_q [RS_DEPTH],
    input rs_entry_t  ev1_q [RS_DEPTH],
    input rs_entry_t  od0_q [RS_DEPTH],
    input rs_entry_t  od1_q [RS_DEPTH],
    input int         self_lane
  );
    if (!entry.valid)
      return 1'b0;
    if (rs_producer_busy(entry.packet.rs1, entry.packet.rs1_use,
                         ev0_q, ev1_q, od0_q, od1_q, self_lane))
      return 1'b0;
    if (rs_producer_busy(entry.packet.rs2, entry.packet.rs2_use,
                         ev0_q, ev1_q, od0_q, od1_q, self_lane))
      return 1'b0;
    return 1'b1;
  endfunction

  // -----------------------------------------------------------------------
  // WB bypass — youngest in-order write wins on rd match
  // -----------------------------------------------------------------------
  function automatic word_t youngest_fwd(
    input gpr_addr_t rs_addr,
    input word_t     rs_data
  );
    word_t y_data;
    word_t y_pc;
    logic  y_hit;

    y_data = rs_data;
    y_pc   = '0;
    y_hit  = 1'b0;

    if (wb0_reg_write && (wb0_rd_addr == rs_addr)) begin
      y_data = wb0_data;
      y_pc   = wb0_pc;
      y_hit  = 1'b1;
    end
    if (wb1_reg_write && (wb1_rd_addr == rs_addr) &&
        (!y_hit || (wb1_pc >= y_pc))) begin
      y_data = wb1_data;
      y_pc   = wb1_pc;
      y_hit  = 1'b1;
    end

    return y_data;
  endfunction

  function automatic word_t fwd_operand(
    input logic      issue_en,
    input gpr_addr_t rs_addr,
    input word_t     rs_data
  );
    if (!issue_en)
      return '0;
    return youngest_fwd(rs_addr, rs_data);
  endfunction

  // -----------------------------------------------------------------------
  // Issue — head of each lane queue
  // -----------------------------------------------------------------------
  rs_entry_t ev0_head, ev1_head, od0_head, od1_head;
  logic      ev0_issue, ev1_issue, od0_issue, od1_issue;

  assign ev0_head  = ev0_bank[ev0_rptr[RS_AW-1:0]];
  assign ev1_head  = ev1_bank[ev1_rptr[RS_AW-1:0]];
  assign od0_head  = od0_bank[od0_rptr[RS_AW-1:0]];
  assign od1_head  = od1_bank[od1_rptr[RS_AW-1:0]];

  assign ev0_issue = enable && !flush && (ev0_count != 0) &&
                     rs_entry_ready(ev0_head, ev0_bank, ev1_bank, od0_bank, od1_bank, 0);
  assign ev1_issue = enable && !flush && (ev1_count != 0) &&
                     rs_entry_ready(ev1_head, ev0_bank, ev1_bank, od0_bank, od1_bank, 1);
  assign od0_issue = enable && !flush && (od0_count != 0) &&
                     rs_entry_ready(od0_head, ev0_bank, ev1_bank, od0_bank, od1_bank, 2);
  assign od1_issue = enable && !flush && (od1_count != 0) &&
                     rs_entry_ready(od1_head, ev0_bank, ev1_bank, od0_bank, od1_bank, 3);

  assign ev0_enable_ex   = ev0_issue;
  assign ev0_opcode_ex   = ev0_head.packet.opcode;
  assign ev0_funct3_ex   = ev0_head.packet.funct3;
  assign ev0_funct7_ex   = ev0_head.packet.funct7;
  assign ev0_rd_ex       = ev0_head.renamed_tag;
  assign ev0_rs1_addr_ex = ev0_head.packet.rs1;
  assign ev0_rs2_addr_ex = ev0_head.packet.rs2;
  assign ev0_imm_ex      = ev0_head.packet.imm;
  assign ev0_rs1_data_ex = fwd_operand(ev0_issue, ev0_head.packet.rs1, ev0_head.packet.rs1_data);
  assign ev0_rs2_data_ex = fwd_operand(ev0_issue, ev0_head.packet.rs2, ev0_head.packet.rs2_data);
  assign ev0_pc_ex       = ev0_head.packet.pc;

  assign ev1_enable_ex   = ev1_issue;
  assign ev1_opcode_ex   = ev1_head.packet.opcode;
  assign ev1_funct3_ex   = ev1_head.packet.funct3;
  assign ev1_funct7_ex   = ev1_head.packet.funct7;
  assign ev1_rd_ex       = ev1_head.renamed_tag;
  assign ev1_rs1_addr_ex = ev1_head.packet.rs1;
  assign ev1_rs2_addr_ex = ev1_head.packet.rs2;
  assign ev1_imm_ex      = ev1_head.packet.imm;
  assign ev1_rs1_data_ex = fwd_operand(ev1_issue, ev1_head.packet.rs1, ev1_head.packet.rs1_data);
  assign ev1_rs2_data_ex = fwd_operand(ev1_issue, ev1_head.packet.rs2, ev1_head.packet.rs2_data);
  assign ev1_pc_ex       = ev1_head.packet.pc;

  assign od0_enable_ex   = od0_issue;
  assign od0_opcode_ex   = od0_head.packet.opcode;
  assign od0_funct3_ex   = od0_head.packet.funct3;
  assign od0_rd_ex       = od0_head.renamed_tag;
  assign od0_rs1_addr_ex = od0_head.packet.rs1;
  assign od0_rs2_addr_ex = od0_head.packet.rs2;
  assign od0_imm_ex      = od0_head.packet.imm;
  assign od0_rs1_data_ex = fwd_operand(od0_issue, od0_head.packet.rs1, od0_head.packet.rs1_data);
  assign od0_rs2_data_ex = fwd_operand(od0_issue, od0_head.packet.rs2, od0_head.packet.rs2_data);
  assign od0_pc_ex       = od0_head.packet.pc;

  assign od1_enable_ex   = od1_issue;
  assign od1_opcode_ex   = od1_head.packet.opcode;
  assign od1_funct3_ex   = od1_head.packet.funct3;
  assign od1_rd_ex       = od1_head.renamed_tag;
  assign od1_rs1_addr_ex = od1_head.packet.rs1;
  assign od1_rs2_addr_ex = od1_head.packet.rs2;
  assign od1_imm_ex      = od1_head.packet.imm;
  assign od1_rs1_data_ex = fwd_operand(od1_issue, od1_head.packet.rs1, od1_head.packet.rs1_data);
  assign od1_rs2_data_ex = fwd_operand(od1_issue, od1_head.packet.rs2, od1_head.packet.rs2_data);
  assign od1_pc_ex       = od1_head.packet.pc;

  assign i0_reg_write_ex = i0_reg_write_disp;
  assign i1_reg_write_ex = i1_reg_write_disp;
  assign i0_pc_ex        = i0_pc_disp;
  assign i1_pc_ex        = i1_pc_disp;

  // -----------------------------------------------------------------------
  // Allocate / retire — one push per dispatch enable, one pop per issue
  // -----------------------------------------------------------------------
  function automatic rs_cnt_t rs_alloc(
    input rs_cnt_t count,
    input logic    push
  );
    return count + {2'b0, push};
  endfunction

  function automatic rs_cnt_t rs_retire(
    input rs_cnt_t count,
    input logic    pop
  );
    return count - {2'b0, pop};
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      ev0_wptr <= '0; ev0_rptr <= '0; ev0_count <= '0;
      ev1_wptr <= '0; ev1_rptr <= '0; ev1_count <= '0;
      od0_wptr <= '0; od0_rptr <= '0; od0_count <= '0;
      od1_wptr <= '0; od1_rptr <= '0; od1_count <= '0;
      for (int i = 0; i < RS_DEPTH; i++) begin
        ev0_bank[i] <= '0;
        ev1_bank[i] <= '0;
        od0_bank[i] <= '0;
        od1_bank[i] <= '0;
      end
    end else if (enable) begin
      if (ev0_in_pkt.valid && (ev0_count < RS_DEPTH)) begin
        ev0_bank[ev0_wptr[RS_AW-1:0]] <= rs_entry_from_ex(ev0_in_pkt);
        ev0_wptr <= ev0_wptr + 1'b1;
      end
      if (ev1_in_pkt.valid && (ev1_count < RS_DEPTH)) begin
        ev1_bank[ev1_wptr[RS_AW-1:0]] <= rs_entry_from_ex(ev1_in_pkt);
        ev1_wptr <= ev1_wptr + 1'b1;
      end
      if (od0_in_pkt.valid && (od0_count < RS_DEPTH)) begin
        od0_bank[od0_wptr[RS_AW-1:0]] <= rs_entry_from_ex(od0_in_pkt);
        od0_wptr <= od0_wptr + 1'b1;
      end
      if (od1_in_pkt.valid && (od1_count < RS_DEPTH)) begin
        od1_bank[od1_wptr[RS_AW-1:0]] <= rs_entry_from_ex(od1_in_pkt);
        od1_wptr <= od1_wptr + 1'b1;
      end

      if (ev0_issue) ev0_rptr <= ev0_rptr + 1'b1;
      if (ev1_issue) ev1_rptr <= ev1_rptr + 1'b1;
      if (od0_issue) od0_rptr <= od0_rptr + 1'b1;
      if (od1_issue) od1_rptr <= od1_rptr + 1'b1;

      ev0_count <= rs_retire(rs_alloc(ev0_count, ev0_in_pkt.valid && (ev0_count < RS_DEPTH)), ev0_issue);
      ev1_count <= rs_retire(rs_alloc(ev1_count, ev1_in_pkt.valid && (ev1_count < RS_DEPTH)), ev1_issue);
      od0_count <= rs_retire(rs_alloc(od0_count, od0_in_pkt.valid && (od0_count < RS_DEPTH)), od0_issue);
      od1_count <= rs_retire(rs_alloc(od1_count, od1_in_pkt.valid && (od1_count < RS_DEPTH)), od1_issue);
    end
  end

endmodule
