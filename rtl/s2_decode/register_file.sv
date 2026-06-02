`timescale 1ns / 1ps

// Dual-issue scalar GPR (32x32): 4 read + 2 write ports (project_outline SS4-5).
// x0 reads as zero; writes to x0 ignored. Same-cycle write to same rd: higher wpc wins.
module register_file
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Even lane read (ID) — ALU rs1 / rs2
  input  logic [4:0]  even_rs1_addr,
  input  logic [4:0]  even_rs2_addr,
  output reg_t        even_rs1_data,
  output reg_t        even_rs2_data,

  // Odd lane read (ID) — load/store / branch rs1 / rs2
  input  logic [4:0]  odd_rs1_addr,
  input  logic [4:0]  odd_rs2_addr,
  output reg_t        odd_rs1_data,
  output reg_t        odd_rs2_data,

  // Even lane write (WB)
  input  logic        even_wen,
  input  logic [4:0]  even_rd,
  input  reg_t        even_wdata,
  input  reg_t        even_wpc,

  // Odd lane write (WB)
  input  logic        odd_wen,
  input  logic [4:0]  odd_rd,
  input  reg_t        odd_wdata,
  input  reg_t        odd_wpc
);

  // x1-x31 stored; x0 is not physical storage
  reg_t regs [1:NUM_GPR-1];

  logic even_wr;
  logic odd_wr;
  logic same_rd;
  logic odd_wins;

  assign even_wr = even_wen && (even_rd != 5'd0);
  assign odd_wr  = odd_wen  && (odd_rd  != 5'd0);
  assign same_rd = even_wr && odd_wr && (even_rd == odd_rd);
  assign odd_wins  = same_rd && (odd_wpc >= even_wpc);

  function automatic reg_t rf_array_read(input logic [4:0] addr);
    if (addr == 5'd0)
      rf_array_read = '0;
    else
      rf_array_read = regs[addr];
  endfunction

  function automatic reg_t rf_read_port(input logic [4:0] addr);
    reg_t         stored;
    logic         even_byp, odd_byp;
    reg_t         wdata;

    stored   = rf_array_read(addr);
    even_byp = even_wr && (even_rd == addr);
    odd_byp  = odd_wr  && (odd_rd  == addr);

    if (even_byp && odd_byp)
      wdata = odd_wins ? odd_wdata : even_wdata;
    else if (odd_byp)
      wdata = odd_wdata;
    else if (even_byp)
      wdata = even_wdata;
    else
      wdata = stored;

    rf_read_port = wdata;
  endfunction

  assign even_rs1_data = rf_read_port(even_rs1_addr);
  assign even_rs2_data = rf_read_port(even_rs2_addr);
  assign odd_rs1_data  = rf_read_port(odd_rs1_addr);
  assign odd_rs2_data  = rf_read_port(odd_rs2_addr);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < NUM_GPR; i++)
        regs[i] <= '0;
    end else begin
      if (even_wr && !odd_wins)
        regs[even_rd] <= even_wdata;
      if (odd_wr && (!same_rd || odd_wins))
        regs[odd_rd] <= odd_wdata;
    end
  end

endmodule
