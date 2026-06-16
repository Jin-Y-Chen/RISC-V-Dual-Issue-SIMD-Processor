`timescale 1ns / 1ps

// EX/MEM-WB pipeline registers — 4 lane copies (ev0/ev1 EX bank, od0/od1 MEM bank).
// Odd lane WB mux + forward tap. Retire candidates (push0/push1) connect directly to GPR ports in top.
module ex_mem_wb
  import rv_dis_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        stall_i0,
  input  logic        stall_i1,

  // --- ev0 / ev1 from EX (even copy, slot I0 / I1) ---
  input  logic        ev0_reg_write_ex,
  input  logic [4:0]  ev0_rd_addr_ex,
  input  reg_t        ev0_wdata_ex,
  input  reg_t        ev0_pc_ex,

  input  logic        ev1_reg_write_ex,
  input  logic [4:0]  ev1_rd_addr_ex,
  input  reg_t        ev1_wdata_ex,
  input  reg_t        ev1_pc_ex,

  // --- od0 / od1 from MEM (odd copy, slot I0 / I1) ---
  input  logic        od0_reg_write_mem,
  input  logic [4:0]  od0_rd_addr_mem,
  input  reg_t        od0_pc_mem,
  input  logic        od0_use_link_mem,
  input  reg_t        od0_alu_result_mem,
  input  logic        od0_mem_en_mem,
  input  logic        od0_mem_act_mem,
  input  reg_t        od0_load_mem_data,

  input  logic        od1_reg_write_mem,
  input  logic [4:0]  od1_rd_addr_mem,
  input  reg_t        od1_pc_mem,
  input  logic        od1_use_link_mem,
  input  reg_t        od1_alu_result_mem,
  input  logic        od1_mem_en_mem,
  input  logic        od1_mem_act_mem,
  input  reg_t        od1_load_mem_data,

  // --- EX/WB stage (even forward / mem0) ---
  output logic        ev0_reg_write_exwb,
  output logic [4:0]  ev0_rd_addr_exwb,
  output reg_t        ev0_wdata_exwb,
  output reg_t        ev0_pc_exwb,

  output logic        ev1_reg_write_exwb,
  output logic [4:0]  ev1_rd_addr_exwb,
  output reg_t        ev1_wdata_exwb,
  output reg_t        ev1_pc_exwb,

  // --- Odd MEM-stage WB data (comb, for forward mem0/mem1) ---
  output reg_t        od0_wdata_mem,
  output reg_t        od1_wdata_mem,

  // --- 4→2 retire push (slot I0 then I1, when pipeline advances) ---
  output logic        push0_valid,
  output logic [4:0]  push0_rd,
  output reg_t        push0_wdata,
  output reg_t        push0_pc,

  output logic        push1_valid,
  output logic [4:0]  push1_rd,
  output reg_t        push1_wdata,
  output reg_t        push1_pc
);

  logic        od0_odd_load_mem;
  logic        od1_odd_load_mem;

  logic        od0_reg_write_memwb;
  logic [4:0]  od0_rd_addr_memwb;
  reg_t        od0_wdata_memwb;
  reg_t        od0_pc_memwb;

  logic        od1_reg_write_memwb;
  logic [4:0]  od1_rd_addr_memwb;
  reg_t        od1_wdata_memwb;
  reg_t        od1_pc_memwb;

  assign od0_odd_load_mem = od0_reg_write_mem && od0_mem_en_mem && !od0_mem_act_mem;
  assign od1_odd_load_mem = od1_reg_write_mem && od1_mem_en_mem && !od1_mem_act_mem;

  assign od0_wdata_mem = od0_odd_load_mem ? od0_load_mem_data :
                         od0_use_link_mem ? (od0_pc_mem + 32'd4) :
                         od0_alu_result_mem;

  assign od1_wdata_mem = od1_odd_load_mem ? od1_load_mem_data :
                         od1_use_link_mem ? (od1_pc_mem + 32'd4) :
                         od1_alu_result_mem;

  // EX/WB — even lane
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      ev0_reg_write_exwb <= 1'b0;
      ev0_rd_addr_exwb   <= 5'd0;
      ev0_wdata_exwb     <= '0;
      ev0_pc_exwb        <= '0;

      ev1_reg_write_exwb <= 1'b0;
      ev1_rd_addr_exwb   <= 5'd0;
      ev1_wdata_exwb     <= '0;
      ev1_pc_exwb        <= '0;
    end else begin
      if (!stall_i0) begin
        ev0_reg_write_exwb <= ev0_reg_write_ex;
        ev0_rd_addr_exwb   <= ev0_rd_addr_ex;
        ev0_wdata_exwb     <= ev0_wdata_ex;
        ev0_pc_exwb        <= ev0_pc_ex;
      end

      if (!stall_i1) begin
        ev1_reg_write_exwb <= ev1_reg_write_ex;
        ev1_rd_addr_exwb   <= ev1_rd_addr_ex;
        ev1_wdata_exwb     <= ev1_wdata_ex;
        ev1_pc_exwb        <= ev1_pc_ex;
      end
    end
  end

  // MEM/WB — odd lane
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      od0_reg_write_memwb <= 1'b0;
      od0_rd_addr_memwb   <= 5'd0;
      od0_wdata_memwb     <= '0;
      od0_pc_memwb        <= '0;

      od1_reg_write_memwb <= 1'b0;
      od1_rd_addr_memwb   <= 5'd0;
      od1_wdata_memwb     <= '0;
      od1_pc_memwb        <= '0;
    end else begin
      if (!stall_i0) begin
        od0_reg_write_memwb <= od0_reg_write_mem;
        od0_rd_addr_memwb   <= od0_rd_addr_mem;
        od0_wdata_memwb     <= od0_wdata_mem;
        od0_pc_memwb        <= od0_pc_mem;
      end

      if (!stall_i1) begin
        od1_reg_write_memwb <= od1_reg_write_mem;
        od1_rd_addr_memwb   <= od1_rd_addr_mem;
        od1_wdata_memwb     <= od1_wdata_mem;
        od1_pc_memwb        <= od1_pc_mem;
      end
    end
  end

  // 4-port enable merge → slot I0/I1 retire when pipeline advances (direct GPR write in top)
  assign push0_valid = !stall_i0 && (ev0_reg_write_ex | od0_reg_write_mem);
  assign push0_rd    = ev0_reg_write_ex ? ev0_rd_addr_ex : od0_rd_addr_mem;
  assign push0_wdata = ev0_reg_write_ex ? ev0_wdata_ex   : od0_wdata_mem;
  assign push0_pc    = ev0_reg_write_ex ? ev0_pc_ex      : od0_pc_mem;

  assign push1_valid = !stall_i1 && (ev1_reg_write_ex | od1_reg_write_mem);
  assign push1_rd    = ev1_reg_write_ex ? ev1_rd_addr_ex : od1_rd_addr_mem;
  assign push1_wdata = ev1_reg_write_ex ? ev1_wdata_ex   : od1_wdata_mem;
  assign push1_pc    = ev1_reg_write_ex ? ev1_pc_ex      : od1_pc_mem;

endmodule
