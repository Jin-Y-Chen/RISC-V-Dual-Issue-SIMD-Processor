`timescale 1ns / 1ps

// L1 data cache model (RV32I byte-addressed, dual-port).
// - L2 backing array holds data; l1_valid tracks resident 32-byte lines
// - Miss: cache_busy until L2_FILL_CYCLES (status only; dispatch owns stall_id)
// - Hit: combinational read / posedge write on l2 backing store
// - RAW/WAR ordering: dispatch stalls/replays; cache assumes in-order MEM arrival except:
//     WAW — suppress I0 (older) store when both ports write overlapping bytes same word
//     WAR — combinational read (I0 load) sees pre-write array; I1 store commits at posedge
//
// Port map: i0 (older), i1 (younger) — dual-issue memory slots.
module memory_cache
  import rv_dis_pkg::*;
#(
  parameter int BYTE_COUNT     = M_SIZE / 8,
  parameter int LINE_BYTES     = 32,
  parameter int L2_FILL_CYCLES = 4,
  parameter bit COLD_L1_RESET  = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        i0_act,       // 0=read, 1=write; |i0_besel gates activity
  input  logic [31:0] i0_addr,
  input  logic [31:0] i0_wdata,
  input  logic [3:0]  i0_besel,
  output logic [31:0] i0_mem_data,

  input  logic        i1_act,
  input  logic [31:0] i1_addr,
  input  logic [31:0] i1_wdata,
  input  logic [3:0]  i1_besel,
  output logic [31:0] i1_mem_data,

  output logic        cache_busy    // miss/fill in progress (not a stall export)
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

  logic [BYTE_AW-1:0] i0_rbase;
  logic [BYTE_AW-1:0] i1_rbase;
  logic [BYTE_AW-1:0] i0_wbase;
  logic [BYTE_AW-1:0] i1_wbase;

  logic        i0_req;
  logic        i1_req;
  logic        i0_read;
  logic        i1_read;
  logic        i0_write;
  logic        i1_write;
  logic        i0_hit;
  logic        i1_hit;
  logic        i0_miss;
  logic        i1_miss;
  logic        same_word;
  logic        besel_overlap;
  logic        suppress_i0_write;

  fill_state_e              fill_state;
  logic [FILL_CNT_W-1:0]    fill_cnt;
  logic [LINE_IDX_AW-1:0]   fill_line;
  logic                     fill_done;

  logic [LINE_IDX_AW-1:0] i0_line_idx;
  logic [LINE_IDX_AW-1:0] i1_line_idx;
  logic                   i0_l1_hit;
  logic                   i1_l1_hit;

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

  assign i0_line_idx = line_index(i0_addr);
  assign i1_line_idx = line_index(i1_addr);
  assign fill_done   = (fill_state == ST_FILL) && (fill_cnt == FILL_LAST);

  assign i0_l1_hit = l1_valid[i0_line_idx] ||
                     (fill_done && (i0_line_idx == fill_line));
  assign i1_l1_hit = l1_valid[i1_line_idx] ||
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

  assign same_word      = (i0_rbase == i1_rbase) && i0_req && i1_req;
  assign besel_overlap  = |(i0_besel & i1_besel);
  assign suppress_i0_write = same_word && i0_write && i1_write && besel_overlap;

  assign cache_busy = ((fill_state == ST_FILL) && !fill_done) ||
                      ((fill_state == ST_IDLE) && (i0_miss || i1_miss));

  always_comb begin
    i0_mem_data = 32'd0;
    i1_mem_data = 32'd0;

    // WAR: comb read from array before posedge writes (I0 load, I1 store same word OK)
    if (i0_read && i0_hit && !cache_busy)
      i0_mem_data = read_le_word(i0_rbase);
    if (i1_read && i1_hit && !cache_busy)
      i1_mem_data = read_le_word(i1_rbase);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fill_state <= ST_IDLE;
      fill_cnt   <= '0;
      fill_line  <= '0;
      l1_valid   <= COLD_L1_RESET ? '0 : {LINE_COUNT{1'b1}};

      for (i = 0; i < BYTE_COUNT; i++)
        l2_array[i] <= 8'd0;
    end else begin
      if (fill_done)
        l1_valid[fill_line] <= 1'b1;

      unique case (fill_state)
        ST_IDLE: begin
          if (i0_miss || i1_miss) begin
            fill_state <= ST_FILL;
            fill_cnt   <= L2_FILL_CYCLES[FILL_CNT_W-1:0];
            fill_line  <= i0_miss ? line_index(i0_addr) : line_index(i1_addr);
          end

          if (i0_write && i0_hit && !cache_busy && !suppress_i0_write) begin
            if (i0_besel[0]) l2_array[i0_wbase + 0] <= i0_wdata[7:0];
            if (i0_besel[1]) l2_array[i0_wbase + 1] <= i0_wdata[15:8];
            if (i0_besel[2]) l2_array[i0_wbase + 2] <= i0_wdata[23:16];
            if (i0_besel[3]) l2_array[i0_wbase + 3] <= i0_wdata[31:24];
          end

          if (i1_write && i1_hit && !cache_busy) begin
            if (i1_besel[0]) l2_array[i1_wbase + 0] <= i1_wdata[7:0];
            if (i1_besel[1]) l2_array[i1_wbase + 1] <= i1_wdata[15:8];
            if (i1_besel[2]) l2_array[i1_wbase + 2] <= i1_wdata[23:16];
            if (i1_besel[3]) l2_array[i1_wbase + 3] <= i1_wdata[31:24];
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
