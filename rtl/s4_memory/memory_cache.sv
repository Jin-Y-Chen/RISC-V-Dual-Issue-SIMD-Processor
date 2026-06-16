`timescale 1ns / 1ps

// L1 data cache model (RV32I byte-addressed, dual-port).
// - L2 backing array holds data; l1_valid tracks resident 32-byte lines
// - Miss: assert stall_p0/stall_p1, wait L2_FILL_CYCLES, then set line valid
// - Hit: combinational read / posedge write on l2 backing store
// - Memory RAW/WAR/WAW ordering is enforced in-order at dispatch before requests
//   reach this block; no same-word hazard logic here.
//
// Port map: p0 = I0 (older), p1 = I1 (younger).
module memory_cache
  import rv_dis_pkg::*;
#(
  parameter int BYTE_COUNT      = M_SIZE / 8,
  parameter int LINE_BYTES      = 32,
  parameter int L2_FILL_CYCLES  = 4,
  parameter bit COLD_L1_RESET = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        p0_read_en,
  input  logic        p0_write_en,
  input  logic [31:0] p0_addr,
  input  logic [31:0] p0_wdata,
  input  logic [3:0]  p0_besel,
  output logic [31:0] p0_rdata,

  input  logic        p1_read_en,
  input  logic        p1_write_en,
  input  logic [31:0] p1_addr,
  input  logic [31:0] p1_wdata,
  input  logic [3:0]  p1_besel,
  output logic [31:0] p1_rdata,

  output logic        stall_p0,
  output logic        stall_p1
);

  localparam int BYTE_AW     = $clog2(BYTE_COUNT);
  localparam int LINE_AW     = $clog2(LINE_BYTES);
  localparam int LINE_COUNT  = BYTE_COUNT / LINE_BYTES;
  localparam int LINE_IDX_AW = $clog2(LINE_COUNT);
  localparam int FILL_CNT_W  = $clog2(L2_FILL_CYCLES + 1);
  localparam logic [FILL_CNT_W-1:0] FILL_LAST = 1'b1;

  typedef enum logic {ST_IDLE, ST_FILL} fill_state_e;

  logic [7:0]              l2_array [0:BYTE_COUNT-1];
  logic [LINE_COUNT-1:0]   l1_valid;

  logic [BYTE_AW-1:0] p0_rbase;
  logic [BYTE_AW-1:0] p1_rbase;
  logic [BYTE_AW-1:0] p0_wbase;
  logic [BYTE_AW-1:0] p1_wbase;

  logic        p0_req;
  logic        p1_req;
  logic        p0_hit;
  logic        p1_hit;
  logic        p0_miss;
  logic        p1_miss;

  fill_state_e              fill_state;
  logic [FILL_CNT_W-1:0]    fill_cnt;
  logic [LINE_IDX_AW-1:0]   fill_line;
  logic                     miss_stall_p0_q;
  logic                     miss_stall_p1_q;
  logic                     fill_done;

  logic [LINE_IDX_AW-1:0] p0_line_idx;
  logic [LINE_IDX_AW-1:0] p1_line_idx;
  logic                   p0_l1_hit;
  logic                   p1_l1_hit;

  integer i;

  function automatic logic [BYTE_AW-1:0] byte_word_base(input logic [31:0] byte_addr);
    return byte_addr[BYTE_AW-1:2] << 2;
  endfunction

  function automatic logic [LINE_IDX_AW-1:0] line_index(input logic [31:0] byte_addr);
    return byte_addr[BYTE_AW-1:LINE_AW];
  endfunction

  function automatic logic [31:0] read_le_word(input logic [BYTE_AW-1:0] base);
    read_le_word = {
      l2_array[base + 3],
      l2_array[base + 2],
      l2_array[base + 1],
      l2_array[base + 0]
    };
  endfunction

  assign p0_line_idx = line_index(p0_addr);
  assign p1_line_idx = line_index(p1_addr);
  assign p0_l1_hit   = l1_valid[p0_line_idx] ||
                       (fill_done && (p0_line_idx == fill_line));
  assign p1_l1_hit   = l1_valid[p1_line_idx] ||
                       (fill_done && (p1_line_idx == fill_line));

  assign p0_req = p0_read_en || (p0_write_en && (|p0_besel));
  assign p1_req = p1_read_en || (p1_write_en && (|p1_besel));

  assign p0_hit  = !p0_req || p0_l1_hit;
  assign p1_hit  = !p1_req || p1_l1_hit;
  assign p0_miss = p0_req && !p0_l1_hit;
  assign p1_miss = p1_req && !p1_l1_hit;

  assign p0_rbase = byte_word_base(p0_addr);
  assign p1_rbase = byte_word_base(p1_addr);
  assign p0_wbase = byte_word_base(p0_addr);
  assign p1_wbase = byte_word_base(p1_addr);

  assign stall_p0 = miss_stall_p0_q;
  assign stall_p1 = miss_stall_p1_q;

  assign fill_done = (fill_state == ST_FILL) && (fill_cnt == FILL_LAST);

  always_comb begin
    p0_rdata = 32'd0;
    p1_rdata = 32'd0;

    if (p0_read_en && p0_hit && !stall_p0)
      p0_rdata = read_le_word(p0_rbase);
    if (p1_read_en && p1_hit && !stall_p1)
      p1_rdata = read_le_word(p1_rbase);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fill_state <= ST_IDLE;
      fill_cnt   <= '0;
      fill_line  <= '0;
      miss_stall_p0_q <= 1'b0;
      miss_stall_p1_q <= 1'b0;
      l1_valid   <= COLD_L1_RESET ? '0 : {LINE_COUNT{1'b1}};

      for (i = 0; i < BYTE_COUNT; i++)
        l2_array[i] <= 8'd0;
    end else begin
      if (fill_done)
        l1_valid[fill_line] <= 1'b1;

      unique case (fill_state)
        ST_IDLE: begin
          if (p0_miss || p1_miss) begin
            fill_state <= ST_FILL;
            fill_cnt   <= L2_FILL_CYCLES[FILL_CNT_W-1:0];
            fill_line  <= p0_miss ? line_index(p0_addr) : line_index(p1_addr);
            miss_stall_p0_q <= p0_miss;
            miss_stall_p1_q <= p1_miss;
          end else begin
            miss_stall_p0_q <= 1'b0;
            miss_stall_p1_q <= 1'b0;
          end

          if (p0_write_en && p0_hit && !stall_p0) begin
            if (p0_besel[0]) l2_array[p0_wbase + 0] <= p0_wdata[7:0];
            if (p0_besel[1]) l2_array[p0_wbase + 1] <= p0_wdata[15:8];
            if (p0_besel[2]) l2_array[p0_wbase + 2] <= p0_wdata[23:16];
            if (p0_besel[3]) l2_array[p0_wbase + 3] <= p0_wdata[31:24];
          end

          if (p1_write_en && p1_hit && !stall_p1) begin
            if (p1_besel[0]) l2_array[p1_wbase + 0] <= p1_wdata[7:0];
            if (p1_besel[1]) l2_array[p1_wbase + 1] <= p1_wdata[15:8];
            if (p1_besel[2]) l2_array[p1_wbase + 2] <= p1_wdata[23:16];
            if (p1_besel[3]) l2_array[p1_wbase + 3] <= p1_wdata[31:24];
          end
        end

        ST_FILL: begin
          if (fill_done) begin
            if (p0_req && (line_index(p0_addr) == fill_line))
              miss_stall_p0_q <= 1'b0;
            if (p1_req && (line_index(p1_addr) == fill_line))
              miss_stall_p1_q <= 1'b0;
            fill_state <= ST_IDLE;
          end else begin
            fill_cnt <= fill_cnt - FILL_LAST;
          end
        end

        default: fill_state <= ST_IDLE;
      endcase
    end
  end

endmodule
