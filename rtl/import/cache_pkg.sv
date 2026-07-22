`timescale 1ns / 1ps
`ifndef CACHE_PKG_SV
`define CACHE_PKG_SV

// Cache helper functions only — geometry (INDEX_W, DATA_W, WAYS, bank[]) lives in each module.
package cache_pkg;

  function [15:0] pc_set;
    input [31:0] pc;
    input integer way_aw;
    input integer set_aw;
    reg [31:0] shifted_pc;
    reg [31:0] set_mask32;
    begin
      pc_set = 16'd0;
      if (set_aw != 0) begin
        shifted_pc = pc >> (way_aw + 2);
        set_mask32 = (32'h1 << set_aw) - 1;
        pc_set     = shifted_pc[15:0] & set_mask32[15:0];
      end
    end
  endfunction

  function [15:0] pc_way;
    input [31:0] pc;
    input integer way_aw;
    reg [31:0] shifted_pc;
    reg [31:0] way_mask32;
    begin
      pc_way = 16'd0;
      if (way_aw != 0) begin
        shifted_pc = pc >> 2;
        way_mask32 = (32'h1 << way_aw) - 1;
        pc_way     = shifted_pc[15:0] & way_mask32[15:0];
      end
    end
  endfunction

  // Flat index decode (same role as pc_set / pc_way, without PC>>2).
  function [15:0] index_set;
    input [15:0] idx;
    input integer way_aw;
    input integer set_aw;
    reg [31:0] set_mask32;
    begin
      index_set = 16'd0;
      if (set_aw != 0) begin
        set_mask32 = (32'h1 << set_aw) - 1;
        index_set  = (idx >> way_aw) & set_mask32[15:0];
      end
    end
  endfunction

  function [15:0] index_way;
    input [15:0] idx;
    input integer way_aw;
    reg [31:0] way_mask32;
    begin
      index_way = 16'd0;
      if (way_aw != 0) begin
        way_mask32 = (32'h1 << way_aw) - 1;
        index_way  = idx & way_mask32[15:0];
      end
    end
  endfunction

  // Packed entry format:
  // - valid bit at entry[data_w]
  // - payload in entry[31:0] (masked to data_w)
  function [31:0] cache_way_read;
    input [32:0] way_entry;
    input [31:0] default_data;
    input integer data_w;
    reg [31:0] mask32;
    begin
      if (data_w >= 32)
        mask32 = 32'hffff_ffff;
      else if (data_w <= 0)
        mask32 = 32'd0;
      else
        mask32 = (32'h1 << data_w) - 1;

      if (way_entry[data_w])
        cache_way_read = way_entry[31:0] & mask32;
      else
        cache_way_read = default_data;
    end
  endfunction

  function [32:0] cache_set_write;
    input        valid;
    input [31:0] data;
    input integer data_w;
    reg [31:0] mask32;
    begin
      if (data_w >= 32)
        mask32 = 32'hffff_ffff;
      else if (data_w <= 0)
        mask32 = 32'd0;
      else
        mask32 = (32'h1 << data_w) - 1;

      cache_set_write         = 33'd0;
      cache_set_write[31:0]   = data & mask32;
      // Set valid after payload so DATA_W<32 does not clear entry[data_w].
      cache_set_write[data_w] = valid;
    end
  endfunction

endpackage
`endif
