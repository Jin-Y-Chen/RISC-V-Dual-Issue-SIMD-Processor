`timescale 1ns / 1ps

// Dual-slot reservation station (even/odd) for one execute side (even or odd).
// IS_ODD=0: even lanes (funct7 used); IS_ODD=1: odd lanes.
// WB bypass (youngest PC wins) is applied at issue; peer banks feed cross-side RAW.
import rv_dis_pkg::*;
import decode_pkg::*;
import rob_rename_pkg::*;

module reservation_station #(
  parameter bit IS_ODD = 1'b0
) (
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

  // dispatch in — slot0 / slot1 (ev0/ev1 or od0/od1)
  input  logic        s0_enable_disp,
  input  opcode_t     s0_opcode_disp,
  input  funct3_t     s0_funct3_disp,
  input  funct7_t     s0_funct7_disp,
  input  gpr_addr_t   s0_rd_disp,
  input  gpr_addr_t   s0_rs1_addr_disp,
  input  gpr_addr_t   s0_rs2_addr_disp,
  input  word_t       s0_imm_disp,
  input  word_t       s0_rs1_data_disp,
  input  word_t       s0_rs2_data_disp,
  input  word_t       s0_pc_disp,

  input  logic        s1_enable_disp,
  input  opcode_t     s1_opcode_disp,
  input  funct3_t     s1_funct3_disp,
  input  funct7_t     s1_funct7_disp,
  input  gpr_addr_t   s1_rd_disp,
  input  gpr_addr_t   s1_rs1_addr_disp,
  input  gpr_addr_t   s1_rs2_addr_disp,
  input  word_t       s1_imm_disp,
  input  word_t       s1_rs1_data_disp,
  input  word_t       s1_rs2_data_disp,
  input  word_t       s1_pc_disp,

  // writeback — operand bypass at issue
  input  logic        wb0_reg_write,
  input  gpr_addr_t   wb0_rd_addr,
  input  word_t       wb0_data,
  input  word_t       wb0_pc,
  input  logic        wb1_reg_write,
  input  gpr_addr_t   wb1_rd_addr,
  input  word_t       wb1_data,
  input  word_t       wb1_pc,

  // peer RS banks (other side) for cross-lane RAW
  input  rs_entry_t   peer0_bank [0:RS_DEPTH-1],
  input  rs_entry_t   peer1_bank [0:RS_DEPTH-1],

  // parent-owned local banks (shared with peer via ref)
  ref    rs_entry_t   bank0 [0:RS_DEPTH-1],
  ref    rs_entry_t   bank1 [0:RS_DEPTH-1],

  // execute out — issued packets (operands already WB-forwarded)
  output logic        s0_enable_ex,
  output opcode_t     s0_opcode_ex,
  output funct3_t     s0_funct3_ex,
  output funct7_t     s0_funct7_ex,
  output gpr_addr_t   s0_rd_ex,
  output gpr_addr_t   s0_rs1_addr_ex,
  output gpr_addr_t   s0_rs2_addr_ex,
  output word_t       s0_imm_ex,
  output word_t       s0_rs1_data_ex,
  output word_t       s0_rs2_data_ex,
  output word_t       s0_pc_ex,

  output logic        s1_enable_ex,
  output opcode_t     s1_opcode_ex,
  output funct3_t     s1_funct3_ex,
  output funct7_t     s1_funct7_ex,
  output gpr_addr_t   s1_rd_ex,
  output gpr_addr_t   s1_rs1_addr_ex,
  output gpr_addr_t   s1_rs2_addr_ex,
  output word_t       s1_imm_ex,
  output word_t       s1_rs1_data_ex,
  output word_t       s1_rs2_data_ex,
  output word_t       s1_pc_ex
);

  localparam rs_cnt_t RS_DEPTH_CNT = RS_DEPTH[RS_AW:0];

  rs_cnt_t s0_wptr, s0_rptr, s0_count;
  rs_cnt_t s1_wptr, s1_rptr, s1_count;

  function automatic EX_packet_t disp_packet(
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
    disp_packet.valid              = en;
    disp_packet.renamed_tag        = renamed_tag;
    disp_packet.packet.lane_sel    = IS_ODD;
    disp_packet.packet.reg_write   = reg_write;
    disp_packet.packet.opcode      = opcode;
    disp_packet.packet.funct3      = funct3;
    disp_packet.packet.funct7      = IS_ODD ? 7'd0 : funct7;
    disp_packet.packet.rs1         = rs1;
    disp_packet.packet.rs2         = rs2;
    disp_packet.packet.imm         = imm;
    disp_packet.packet.rs1_data    = rs1_data;
    disp_packet.packet.rs2_data    = rs2_data;
    disp_packet.packet.pc          = pc;
  endfunction

  EX_packet_t s0_in_pkt, s1_in_pkt;

  always_comb begin
    s0_in_pkt = disp_packet(
      s0_enable_disp, i0_reg_write_disp, s0_rd_disp, s0_opcode_disp, s0_funct3_disp, s0_funct7_disp,
      s0_rs1_addr_disp, s0_rs2_addr_disp, s0_imm_disp,
      s0_rs1_data_disp, s0_rs2_data_disp, s0_pc_disp
    );
    s1_in_pkt = disp_packet(
      s1_enable_disp, i1_reg_write_disp, s1_rd_disp, s1_opcode_disp, s1_funct3_disp, s1_funct7_disp,
      s1_rs1_addr_disp, s1_rs2_addr_disp, s1_imm_disp,
      s1_rs1_data_disp, s1_rs2_data_disp, s1_pc_disp
    );
  end

  // RAW — producer in local other slot or peer RS (same-slot younger excluded)
  function automatic logic rs_producer_busy(
    input gpr_addr_t rs,
    input logic      rs_use,
    input int        self_slot
  );
    if (!rs_use)
      return 1'b0;
    for (int i = 0; i < RS_DEPTH; i++) begin
      if ((self_slot != 0) &&
          bank0[i].valid && bank0[i].packet.reg_write && (bank0[i].renamed_tag == rs))
        return 1'b1;
      if ((self_slot != 1) &&
          bank1[i].valid && bank1[i].packet.reg_write && (bank1[i].renamed_tag == rs))
        return 1'b1;
      if (peer0_bank[i].valid && peer0_bank[i].packet.reg_write && (peer0_bank[i].renamed_tag == rs))
        return 1'b1;
      if (peer1_bank[i].valid && peer1_bank[i].packet.reg_write && (peer1_bank[i].renamed_tag == rs))
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function automatic logic rs_entry_ready(
    input rs_entry_t entry,
    input int        self_slot
  );
    if (!entry.valid)
      return 1'b0;
    if (rs_producer_busy(entry.packet.rs1, decode_rs1_use(entry.packet.opcode), self_slot))
      return 1'b0;
    if (rs_producer_busy(entry.packet.rs2, decode_rs2_use(entry.packet.opcode), self_slot))
      return 1'b0;
    return 1'b1;
  endfunction

  // WB bypass — youngest in-order write wins on rd match
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

  rs_entry_t s0_head, s1_head;
  logic      s0_issue, s1_issue;

  assign s0_head  = bank0[s0_rptr[RS_AW-1:0]];
  assign s1_head  = bank1[s1_rptr[RS_AW-1:0]];
  assign s0_issue = enable && !flush && (s0_count != 0) && rs_entry_ready(s0_head, 0);
  assign s1_issue = enable && !flush && (s1_count != 0) && rs_entry_ready(s1_head, 1);

  assign s0_enable_ex   = s0_issue;
  assign s0_opcode_ex   = s0_head.packet.opcode;
  assign s0_funct3_ex   = s0_head.packet.funct3;
  assign s0_funct7_ex   = s0_head.packet.funct7;
  assign s0_rd_ex       = s0_head.renamed_tag;
  assign s0_rs1_addr_ex = s0_head.packet.rs1;
  assign s0_rs2_addr_ex = s0_head.packet.rs2;
  assign s0_imm_ex      = s0_head.packet.imm;
  assign s0_rs1_data_ex = fwd_operand(s0_issue, s0_head.packet.rs1, s0_head.packet.rs1_data);
  assign s0_rs2_data_ex = fwd_operand(s0_issue, s0_head.packet.rs2, s0_head.packet.rs2_data);
  assign s0_pc_ex       = s0_head.packet.pc;

  assign s1_enable_ex   = s1_issue;
  assign s1_opcode_ex   = s1_head.packet.opcode;
  assign s1_funct3_ex   = s1_head.packet.funct3;
  assign s1_funct7_ex   = s1_head.packet.funct7;
  assign s1_rd_ex       = s1_head.renamed_tag;
  assign s1_rs1_addr_ex = s1_head.packet.rs1;
  assign s1_rs2_addr_ex = s1_head.packet.rs2;
  assign s1_imm_ex      = s1_head.packet.imm;
  assign s1_rs1_data_ex = fwd_operand(s1_issue, s1_head.packet.rs1, s1_head.packet.rs1_data);
  assign s1_rs2_data_ex = fwd_operand(s1_issue, s1_head.packet.rs2, s1_head.packet.rs2_data);
  assign s1_pc_ex       = s1_head.packet.pc;

  assign i0_reg_write_ex = i0_reg_write_disp;
  assign i1_reg_write_ex = i1_reg_write_disp;
  assign i0_pc_ex        = i0_pc_disp;
  assign i1_pc_ex        = i1_pc_disp;

  function automatic rs_cnt_t rs_alloc(input rs_cnt_t count, input logic push);
    return count + {2'b0, push};
  endfunction

  function automatic rs_cnt_t rs_retire(input rs_cnt_t count, input logic pop);
    return count - {2'b0, pop};
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      s0_wptr <= '0; s0_rptr <= '0; s0_count <= '0;
      s1_wptr <= '0; s1_rptr <= '0; s1_count <= '0;
      for (int i = 0; i < RS_DEPTH; i++) begin
        bank0[i] <= '0;
        bank1[i] <= '0;
      end
    end else if (enable) begin
      if (s0_in_pkt.valid && (s0_count < RS_DEPTH_CNT)) begin
        bank0[s0_wptr[RS_AW-1:0]] <= rs_entry_from_ex(s0_in_pkt);
        s0_wptr <= s0_wptr + 1'b1;
      end
      if (s1_in_pkt.valid && (s1_count < RS_DEPTH_CNT)) begin
        bank1[s1_wptr[RS_AW-1:0]] <= rs_entry_from_ex(s1_in_pkt);
        s1_wptr <= s1_wptr + 1'b1;
      end

      if (s0_issue) s0_rptr <= s0_rptr + 1'b1;
      if (s1_issue) s1_rptr <= s1_rptr + 1'b1;

      s0_count <= rs_retire(rs_alloc(s0_count, s0_in_pkt.valid && (s0_count < RS_DEPTH_CNT)), s0_issue);
      s1_count <= rs_retire(rs_alloc(s1_count, s1_in_pkt.valid && (s1_count < RS_DEPTH_CNT)), s1_issue);
    end
  end

endmodule
