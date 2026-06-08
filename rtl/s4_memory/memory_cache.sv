`timescale 1ns / 1ps

// Dual-port scalar data memory (byte-addressed RV32I model).
// - Two independent request ports: p0 and p1
// - Each port supports 32-bit read and byte-enable write
// - Address unit is byte; memory array is 32-bit words indexed by addr[31:2]
//
// Write conflict policy (same word, same byte lane in one cycle):
//   p1 has priority over p0 on overlapping byte lanes.
module memory_cache
  import rv_dis_pkg::*;
#(
  parameter int WORD_COUNT = NUM_MADDR
) (
  input  logic        clk,
  input  logic        rst_n,

  // Port 0
  input  logic        p0_read_en,
  input  logic        p0_write_en,
  input  logic [31:0] p0_addr,      // byte address
  input  logic [31:0] p0_wdata,
  input  logic [3:0]  p0_besel,     // byte enables for write
  output logic [31:0] p0_rdata,

  // Port 1
  input  logic        p1_read_en,
  input  logic        p1_write_en,
  input  logic [31:0] p1_addr,      // byte address
  input  logic [31:0] p1_wdata,
  input  logic [3:0]  p1_besel,     // byte enables for write
  output logic [31:0] p1_rdata
);

  localparam int WORD_AW = $clog2(WORD_COUNT);

  logic [31:0] mem_array [0:WORD_COUNT-1];
  logic [WORD_AW-1:0] p0_widx;
  logic [WORD_AW-1:0] p1_widx;
  logic [WORD_AW-1:0] p0_ridx;
  logic [WORD_AW-1:0] p1_ridx;
  integer i;

  assign p0_widx = p0_addr[WORD_AW+1:2];
  assign p1_widx = p1_addr[WORD_AW+1:2];
  assign p0_ridx = p0_addr[WORD_AW+1:2];
  assign p1_ridx = p1_addr[WORD_AW+1:2];

  // Combinational read from current memory contents.
  always_comb begin
    p0_rdata = 32'd0;
    p1_rdata = 32'd0;

    if (p0_read_en) p0_rdata = mem_array[p0_ridx];
    if (p1_read_en) p1_rdata = mem_array[p1_ridx];
  end

  // Synchronous writes with deterministic p1-over-p0 byte-lane priority.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < WORD_COUNT; i++) begin
        mem_array[i] <= 32'd0;
      end
    end else begin
      if (p0_write_en) begin
        if (p0_besel[0]) mem_array[p0_widx][7:0]   <= p0_wdata[7:0];
        if (p0_besel[1]) mem_array[p0_widx][15:8]  <= p0_wdata[15:8];
        if (p0_besel[2]) mem_array[p0_widx][23:16] <= p0_wdata[23:16];
        if (p0_besel[3]) mem_array[p0_widx][31:24] <= p0_wdata[31:24];
      end

      if (p1_write_en) begin
        if (p1_besel[0]) mem_array[p1_widx][7:0]   <= p1_wdata[7:0];
        if (p1_besel[1]) mem_array[p1_widx][15:8]  <= p1_wdata[15:8];
        if (p1_besel[2]) mem_array[p1_widx][23:16] <= p1_wdata[23:16];
        if (p1_besel[3]) mem_array[p1_widx][31:24] <= p1_wdata[31:24];
      end
    end
  end

endmodule
