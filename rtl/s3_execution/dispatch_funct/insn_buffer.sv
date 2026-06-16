`timescale 1ns / 1ps

// In-order FIFO of suppressed instructions (scoreboard replay queue).
// Head = oldest waiting insn; push on partial issue, pop when replay issues.
module insn_buffer
  import rv_dis_pkg::*;
#(
  parameter int DEPTH = 4,
  parameter int MIN_FREE_SLOTS = 2  // push blocked until at least this many slots are free
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        push,
  input  logic        pop,

  // --- push (tail) ---
  input  lane_sel_e   push_lane_sel,
  input  logic [6:0]  push_opcode,
  input  logic [2:0]  push_funct3,
  input  logic [6:0]  push_funct7,
  input  logic [4:0]  push_rd,
  input  logic [4:0]  push_rs1,
  input  logic [4:0]  push_rs2,
  input  logic        push_rs1_use,
  input  logic        push_rs2_use,
  input  logic        push_reg_write,
  input  logic [31:0] push_imm,
  input  logic [31:0] push_rs1_data,
  input  logic [31:0] push_rs2_data,
  input  logic [31:0] push_pc,
  input  logic [4:0]  push_producer_rd,
  input  logic        push_producer_valid,
  input  logic [31:0] push_bundle_i0_pc,
  input  logic [31:0] push_bundle_i1_pc,

  output logic        empty,
  output logic        full,
  output logic [2:0]  count,
  output logic        push_ok,  // at least MIN_FREE_SLOTS empty (headroom before next push)

  // --- head (replay) ---
  output lane_sel_e   head_lane_sel,
  output logic [6:0]  head_opcode,
  output logic [2:0]  head_funct3,
  output logic [6:0]  head_funct7,
  output logic [4:0]  head_rd,
  output logic [4:0]  head_rs1,
  output logic [4:0]  head_rs2,
  output logic        head_rs1_use,
  output logic        head_rs2_use,
  output logic        head_reg_write,
  output logic [31:0] head_imm,
  output logic [31:0] head_rs1_data,
  output logic [31:0] head_rs2_data,
  output logic [31:0] head_pc,
  output logic [4:0]  head_producer_rd,
  output logic        head_producer_valid,
  output logic [31:0] head_bundle_i0_pc,
  output logic [31:0] head_bundle_i1_pc
);

  localparam int PTR_W = (DEPTH <= 2) ? 1 : (DEPTH <= 4) ? 2 : 3;
  localparam int PUSH_OK_MAX_COUNT = DEPTH - MIN_FREE_SLOTS;

  typedef struct packed {
    lane_sel_e   lane_sel;
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic        rs1_use;
    logic        rs2_use;
    logic        reg_write;
    logic [31:0] imm;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] pc;
    logic [4:0]  producer_rd;
    logic        producer_valid;
    logic [31:0] bundle_i0_pc;
    logic [31:0] bundle_i1_pc;
  } entry_t;

  entry_t           mem[DEPTH];
  logic [PTR_W-1:0] head_ptr_q;
  logic [PTR_W-1:0] tail_ptr_q;
  logic [2:0]       count_q;

  assign empty = (count_q == 3'd0);
  assign full  = (count_q == DEPTH[2:0]);
  assign count = count_q;
  assign push_ok = (count_q <= 3'(PUSH_OK_MAX_COUNT));

  assign head_lane_sel        = mem[head_ptr_q].lane_sel;
  assign head_opcode          = mem[head_ptr_q].opcode;
  assign head_funct3          = mem[head_ptr_q].funct3;
  assign head_funct7          = mem[head_ptr_q].funct7;
  assign head_rd              = mem[head_ptr_q].rd;
  assign head_rs1             = mem[head_ptr_q].rs1;
  assign head_rs2             = mem[head_ptr_q].rs2;
  assign head_rs1_use         = mem[head_ptr_q].rs1_use;
  assign head_rs2_use         = mem[head_ptr_q].rs2_use;
  assign head_reg_write       = mem[head_ptr_q].reg_write;
  assign head_imm             = mem[head_ptr_q].imm;
  assign head_rs1_data        = mem[head_ptr_q].rs1_data;
  assign head_rs2_data        = mem[head_ptr_q].rs2_data;
  assign head_pc              = mem[head_ptr_q].pc;
  assign head_producer_rd     = mem[head_ptr_q].producer_rd;
  assign head_producer_valid  = mem[head_ptr_q].producer_valid;
  assign head_bundle_i0_pc    = mem[head_ptr_q].bundle_i0_pc;
  assign head_bundle_i1_pc    = mem[head_ptr_q].bundle_i1_pc;

  function automatic logic [PTR_W-1:0] ptr_inc(input logic [PTR_W-1:0] p);
    if (p == PTR_W'(DEPTH - 1))
      return '0;
    return p + PTR_W'(1);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      head_ptr_q <= '0;
      tail_ptr_q <= '0;
      count_q    <= 3'd0;
    end else begin
      unique case ({push && !full, pop && !empty})
        2'b10: begin
          mem[tail_ptr_q].lane_sel       <= push_lane_sel;
          mem[tail_ptr_q].opcode         <= push_opcode;
          mem[tail_ptr_q].funct3         <= push_funct3;
          mem[tail_ptr_q].funct7         <= push_funct7;
          mem[tail_ptr_q].rd             <= push_rd;
          mem[tail_ptr_q].rs1            <= push_rs1;
          mem[tail_ptr_q].rs2            <= push_rs2;
          mem[tail_ptr_q].rs1_use        <= push_rs1_use;
          mem[tail_ptr_q].rs2_use        <= push_rs2_use;
          mem[tail_ptr_q].reg_write      <= push_reg_write;
          mem[tail_ptr_q].imm            <= push_imm;
          mem[tail_ptr_q].rs1_data       <= push_rs1_data;
          mem[tail_ptr_q].rs2_data       <= push_rs2_data;
          mem[tail_ptr_q].pc             <= push_pc;
          mem[tail_ptr_q].producer_rd    <= push_producer_rd;
          mem[tail_ptr_q].producer_valid <= push_producer_valid;
          mem[tail_ptr_q].bundle_i0_pc   <= push_bundle_i0_pc;
          mem[tail_ptr_q].bundle_i1_pc   <= push_bundle_i1_pc;
          tail_ptr_q                     <= ptr_inc(tail_ptr_q);
          count_q                        <= count_q + 3'd1;
        end
        2'b01: begin
          head_ptr_q <= ptr_inc(head_ptr_q);
          count_q    <= count_q - 3'd1;
        end
        2'b11: begin
          mem[tail_ptr_q].lane_sel       <= push_lane_sel;
          mem[tail_ptr_q].opcode         <= push_opcode;
          mem[tail_ptr_q].funct3         <= push_funct3;
          mem[tail_ptr_q].funct7         <= push_funct7;
          mem[tail_ptr_q].rd             <= push_rd;
          mem[tail_ptr_q].rs1            <= push_rs1;
          mem[tail_ptr_q].rs2            <= push_rs2;
          mem[tail_ptr_q].rs1_use        <= push_rs1_use;
          mem[tail_ptr_q].rs2_use        <= push_rs2_use;
          mem[tail_ptr_q].reg_write      <= push_reg_write;
          mem[tail_ptr_q].imm            <= push_imm;
          mem[tail_ptr_q].rs1_data       <= push_rs1_data;
          mem[tail_ptr_q].rs2_data       <= push_rs2_data;
          mem[tail_ptr_q].pc             <= push_pc;
          mem[tail_ptr_q].producer_rd    <= push_producer_rd;
          mem[tail_ptr_q].producer_valid <= push_producer_valid;
          mem[tail_ptr_q].bundle_i0_pc   <= push_bundle_i0_pc;
          mem[tail_ptr_q].bundle_i1_pc   <= push_bundle_i1_pc;
          tail_ptr_q                     <= ptr_inc(tail_ptr_q);
          head_ptr_q                     <= ptr_inc(head_ptr_q);
        end
        default: ;
      endcase
    end
  end

endmodule
