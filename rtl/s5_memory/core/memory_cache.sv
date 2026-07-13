`timescale 1ns / 1ps

// L1 data cache model (RV32I byte-addressed, dual-port).
// L1 word bank (SETS x WAYS via cache_pkg helpers); l2_array is byte backing store.
// Miss: cache_busy until L2_FILL_CYCLES (status only; dispatch owns stall_id)
// Hit: combinational read; posedge write to l2 + L1 bank entry
// RAW/WAR ordering: dispatch stalls/replays; cache assumes in-order MEM arrival except:
//     WAW — suppress I0 (older) store when both ports write overlapping bytes same word
//     WAR — combinational read (I0 load) sees pre-write array; I1 store commits at posedge
//
// Port map: i0 (older), i1 (younger) — dual-issue memory slots.
import rv_dis_pkg::*;
import cache_pkg::*;

module memory_cache #(
  parameter integer BYTE_COUNT     = M_SIZE / 8,
  parameter integer LINE_BYTES     = 32,
  parameter integer INDEX_W        = PC_INDEX_AW,
  parameter integer DATA_W         = RLEN,
  parameter integer WAYS           = 16,
  parameter integer L2_FILL_CYCLES = 4,
  parameter bit     COLD_L1_RESET  = 1'b1
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,

  input  wire        i0_act,
  input  wire        i1_act,

  input  word_t      i0_addr,
  input  word_t      i0_wdata,
  input  mem_besel_t i0_besel,
  input  word_t      i1_addr,
  input  word_t      i1_wdata,
  input  mem_besel_t i1_besel,

  output reg  [31:0] i0_mem_data,
  output reg  [31:0] i1_mem_data,

  output wire        cache_busy
);

  localparam integer BYTE_AW        = $clog2(BYTE_COUNT);
  localparam integer LINE_AW        = $clog2(LINE_BYTES);
  localparam integer LINE_COUNT     = BYTE_COUNT / LINE_BYTES;
  localparam integer LINE_IDX_AW    = $clog2(LINE_COUNT);
  localparam integer FILL_CNT_W     = $clog2(L2_FILL_CYCLES + 1);
  localparam [3:0] WPL = LINE_BYTES >> 2;
  localparam [FILL_CNT_W-1:0] FILL_LAST = 1'b1;

  localparam integer WAY_AW = (WAYS <= 1) ? 0 : $clog2(WAYS);
  localparam integer SET_AW = INDEX_W - WAY_AW;
  localparam integer SETS   = (1 << INDEX_W) / WAYS;

  localparam [0:0] ST_IDLE = 1'b0;
  localparam [0:0] ST_FILL = 1'b1;

  reg [7:0]            l2_array [0:BYTE_COUNT-1];
  reg [32:0]           bank [0:SETS-1][0:WAYS-1];
  reg [LINE_COUNT-1:0] l1_warm;

  reg [BYTE_AW-1:0] i0_rbase;
  reg [BYTE_AW-1:0] i1_rbase;
  reg [BYTE_AW-1:0] i0_wbase;
  reg [BYTE_AW-1:0] i1_wbase;

  wire        i0_req;
  wire        i1_req;
  wire        i0_read;
  wire        i1_read;
  wire        i0_write;
  wire        i1_write;
  wire        i0_hit;
  wire        i1_hit;
  wire        i0_miss;
  wire        i1_miss;
  wire        same_word;
  wire        besel_overlap;
  wire        suppress_i0_write;

  reg         fill_state;
  reg [FILL_CNT_W-1:0] fill_cnt;
  reg [LINE_IDX_AW-1:0] fill_line;
  wire        fill_done;

  wire [LINE_IDX_AW-1:0] i0_line_idx;
  wire [LINE_IDX_AW-1:0] i1_line_idx;
  wire        i0_l1_hit;
  wire        i1_l1_hit;

  reg [31:0]  i0_word_next;
  reg [31:0]  i1_word_next;
  wire        i0_word_we;
  wire        i1_word_we;

  integer i;
  integer s;
  integer w;
  reg [3:0] fill_w;
  reg [BYTE_AW-1:0] fill_word_base;
  reg [BYTE_AW-1:0] fill_word_off;

  function [BYTE_AW-1:0] byte_word_base;
    input [31:0] byte_addr;
    begin
      byte_word_base = byte_addr[BYTE_AW-1:2] << 2;
    end
  endfunction

  function [LINE_IDX_AW-1:0] line_index;
    input [31:0] byte_addr;
    begin
      line_index = byte_addr[BYTE_AW-1:LINE_AW];
    end
  endfunction

  function [BYTE_AW-1:0] line_byte_base;
    input [LINE_IDX_AW-1:0] line;
    begin
      line_byte_base = line << LINE_AW;
    end
  endfunction

  function [31:0] read_le_word;
    input [BYTE_AW-1:0] base;
    begin
      read_le_word = {
        l2_array[base + 3],
        l2_array[base + 2],
        l2_array[base + 1],
        l2_array[base + 0]
      };
    end
  endfunction

  function entry_valid;
    input [31:0] byte_addr;
    reg [15:0] set_idx;
    reg [15:0] way_idx;
    begin
      set_idx     = pc_set(byte_addr, WAY_AW, SET_AW);
      way_idx     = pc_way(byte_addr, WAY_AW);
      entry_valid = bank[set_idx][way_idx][DATA_W];
    end
  endfunction

  function [31:0] read_cached_word;
    input [31:0] byte_addr;
    reg [BYTE_AW-1:0] base;
    reg [15:0] set_idx;
    reg [15:0] way_idx;
    begin
      base     = byte_word_base(byte_addr);
      set_idx  = pc_set(byte_addr, WAY_AW, SET_AW);
      way_idx  = pc_way(byte_addr, WAY_AW);
      read_cached_word = cache_way_read(
        bank[set_idx][way_idx],
        read_le_word(base),
        DATA_W
      );
    end
  endfunction

  assign i0_line_idx = line_index(i0_addr);
  assign i1_line_idx = line_index(i1_addr);
  assign fill_done   = (fill_state == ST_FILL) && (fill_cnt == FILL_LAST);

  assign i0_l1_hit = entry_valid(i0_addr) || l1_warm[i0_line_idx] ||
                     (fill_done && (i0_line_idx == fill_line));
  assign i1_l1_hit = entry_valid(i1_addr) || l1_warm[i1_line_idx] ||
                     (fill_done && (i1_line_idx == fill_line));

  assign i0_req = |i0_besel;
  assign i1_req = |i1_besel;

  assign i0_read  = i0_req && !i0_act;
  assign i1_read  = i1_req && !i1_act;
  assign i0_write = i0_req &&  i0_act;
  assign i1_write = i1_req &&  i1_act;

  assign i0_hit  = !i0_req || i0_l1_hit;
  assign i1_hit  = !i1_req || i1_l1_hit;
  assign i0_miss = i0_req && !i0_l1_hit;
  assign i1_miss = i1_req && !i1_l1_hit;

  assign i0_rbase = byte_word_base(i0_addr);
  assign i1_rbase = byte_word_base(i1_addr);
  assign i0_wbase = byte_word_base(i0_addr);
  assign i1_wbase = byte_word_base(i1_addr);

  assign same_word         = (i0_rbase == i1_rbase) && i0_req && i1_req;
  assign besel_overlap     = |(i0_besel & i1_besel);
  assign suppress_i0_write = same_word && i0_write && i1_write && besel_overlap;

  assign cache_busy = ((fill_state == ST_FILL) && !fill_done) ||
                       ((fill_state == ST_IDLE) && (i0_miss || i1_miss));

  assign i0_word_we = i0_write && i0_hit && !cache_busy && !suppress_i0_write;
  assign i1_word_we = i1_write && i1_hit && !cache_busy;

  always @(*) begin
    i0_mem_data = 32'd0;
    i1_mem_data = 32'd0;

    if (i0_read && i0_hit && !cache_busy)
      i0_mem_data = read_cached_word(i0_addr);
    if (i1_read && i1_hit && !cache_busy)
      i1_mem_data = read_cached_word(i1_addr);
  end

  always @(*) begin
    i0_word_next = read_le_word(i0_wbase);
    i1_word_next = read_le_word(i1_wbase);

    if (i0_word_we) begin
      if (i0_besel[0]) i0_word_next[7:0]   = i0_wdata[7:0];
      if (i0_besel[1]) i0_word_next[15:8]  = i0_wdata[15:8];
      if (i0_besel[2]) i0_word_next[23:16] = i0_wdata[23:16];
      if (i0_besel[3]) i0_word_next[31:24] = i0_wdata[31:24];
    end

    if (i1_word_we) begin
      if (i1_besel[0]) i1_word_next[7:0]   = i1_wdata[7:0];
      if (i1_besel[1]) i1_word_next[15:8]  = i1_wdata[15:8];
      if (i1_besel[2]) i1_word_next[23:16] = i1_wdata[23:16];
      if (i1_besel[3]) i1_word_next[31:24] = i1_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fill_state <= ST_IDLE;
      fill_cnt   <= {FILL_CNT_W{1'b0}};
      fill_line  <= {LINE_IDX_AW{1'b0}};
      l1_warm    <= COLD_L1_RESET ? {LINE_COUNT{1'b0}} : {LINE_COUNT{1'b1}};

      for (i = 0; i < BYTE_COUNT; i = i + 1)
        l2_array[i] <= 8'd0;

      for (s = 0; s < SETS; s = s + 1) begin
        for (w = 0; w < WAYS; w = w + 1) begin
          bank[s][w] <= 33'd0;
        end
      end
    end else if (enable) begin
      if (fill_done) begin
        for (fill_w = 4'd0; fill_w < WPL; fill_w = fill_w + 1) begin
          fill_word_off  = {{(BYTE_AW-5){1'b0}}, fill_w[2:0], 2'b00};
          fill_word_base = line_byte_base(fill_line) + fill_word_off;
          bank[pc_set({17'd0, fill_word_base}, WAY_AW, SET_AW)]
              [pc_way({17'd0, fill_word_base}, WAY_AW)] <=
            cache_set_write(1'b1, read_le_word(fill_word_base), DATA_W);
        end
        l1_warm[fill_line] <= 1'b1;
      end

      case (fill_state)
        ST_IDLE: begin
          if (i0_miss || i1_miss) begin
            fill_state <= ST_FILL;
            fill_cnt   <= L2_FILL_CYCLES[FILL_CNT_W-1:0];
            fill_line  <= i0_miss ? line_index(i0_addr) : line_index(i1_addr);
          end

          if (i0_word_we) begin
            if (i0_besel[0]) l2_array[i0_wbase + 0] <= i0_word_next[7:0];
            if (i0_besel[1]) l2_array[i0_wbase + 1] <= i0_word_next[15:8];
            if (i0_besel[2]) l2_array[i0_wbase + 2] <= i0_word_next[23:16];
            if (i0_besel[3]) l2_array[i0_wbase + 3] <= i0_word_next[31:24];
            bank[pc_set(i0_addr, WAY_AW, SET_AW)][pc_way(i0_addr, WAY_AW)] <=
              cache_set_write(1'b1, i0_word_next, DATA_W);
          end

          if (i1_word_we) begin
            if (i1_besel[0]) l2_array[i1_wbase + 0] <= i1_word_next[7:0];
            if (i1_besel[1]) l2_array[i1_wbase + 1] <= i1_word_next[15:8];
            if (i1_besel[2]) l2_array[i1_wbase + 2] <= i1_word_next[23:16];
            if (i1_besel[3]) l2_array[i1_wbase + 3] <= i1_word_next[31:24];
            bank[pc_set(i1_addr, WAY_AW, SET_AW)][pc_way(i1_addr, WAY_AW)] <=
              cache_set_write(1'b1, i1_word_next, DATA_W);
          end
        end

        ST_FILL: begin
          if (fill_done)
            fill_state <= ST_IDLE;
          else
            fill_cnt <= fill_cnt - FILL_LAST;
        end

        default: fill_state <= ST_IDLE;
      endcase
    end
  end

endmodule
