`timescale 1ns / 1ps
`ifndef CACHE_PKG_SV
`define CACHE_PKG_SV

// Set-associative prediction/cache helpers.
// Compatibility-focused: avoid parameterized package functions.
package cache_pkg;

  localparam int CACHE_WAYS_MIN = 1;
  localparam int CACHE_WAYS_MAX = 16;

  typedef struct packed {
    int unsigned data_w;
    int unsigned index_w;
    int unsigned set_aw;
    int unsigned way_aw;
    int unsigned sets;
    int unsigned ways;
    int unsigned entry_count;
  } cache_struct_t;

  function automatic cache_struct_t cache_struct_build(
    input int DATA_W,
    input int INDEX_W,
    input int WAYS
  );
    int unsigned way_aw;
    if (WAYS < CACHE_WAYS_MIN) $fatal(1, "cache_pkg: WAYS=%0d too small", WAYS);
    if (WAYS > CACHE_WAYS_MAX) $fatal(1, "cache_pkg: WAYS=%0d too large", WAYS);
    if ((WAYS & (WAYS - 1)) != 0) $fatal(1, "cache_pkg: WAYS=%0d must be power of 2", WAYS);
    way_aw = $clog2(WAYS);
    if (INDEX_W < way_aw) $fatal(1, "cache_pkg: INDEX_W=%0d < way_aw=%0d", INDEX_W, way_aw);

    cache_struct_build.data_w      = DATA_W;
    cache_struct_build.index_w     = INDEX_W;
    cache_struct_build.way_aw      = way_aw;
    cache_struct_build.set_aw      = INDEX_W - way_aw;
    cache_struct_build.ways        = WAYS;
    cache_struct_build.entry_count = (1 << INDEX_W);
    cache_struct_build.sets        = cache_struct_build.entry_count / WAYS;
  endfunction

  function automatic logic [15:0] pc_set(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    logic [31:0] shifted_pc;
    logic [31:0] set_mask32;
    if (cfg.set_aw == 0) return 16'd0;
    shifted_pc = pc >> (cfg.way_aw + 2);
    set_mask32 = (32'h1 << cfg.set_aw) - 1;
    return shifted_pc[15:0] & set_mask32[15:0];
  endfunction

  function automatic logic [15:0] pc_way(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    logic [31:0] shifted_pc;
    logic [31:0] way_mask32;
    if (cfg.way_aw == 0) return 16'd0;
    shifted_pc = pc >> 2;
    way_mask32 = (32'h1 << cfg.way_aw) - 1;
    return shifted_pc[15:0] & way_mask32[15:0];
  endfunction

  // Compatibility aliases kept for existing modules.
  function automatic logic [15:0] bank_set_idx(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    return pc_set(pc, cfg);
  endfunction

  function automatic logic [15:0] bank_way_idx(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    return pc_way(pc, cfg);
  endfunction

  // Packed entry format:
  // - valid bit at entry[data_w]
  // - payload in entry[31:0] (masked to data_w)
  function automatic logic [31:0] cache_set_read(
    input logic [32:0]   set[CACHE_WAYS_MAX],
    input logic [15:0]   way_idx,
    input logic [31:0]   default_data,
    input int            ways,
    input int            data_w
  );
    int way_sel;
    logic [31:0] mask32;
    if (ways <= 1) way_sel = 0;
    else begin
      way_sel = way_idx;
      if (way_sel >= ways) way_sel = 0;
    end

    if (data_w >= 32) mask32 = 32'hffff_ffff;
    else if (data_w <= 0) mask32 = 32'd0;
    else mask32 = (32'h1 << data_w) - 1;

    if (set[way_sel][data_w]) return set[way_sel][31:0] & mask32;
    return default_data;
  endfunction

  function automatic logic [32:0] cache_set_write(
    input logic         valid,
    input logic [31:0]  data,
    input int           data_w
  );
    logic [31:0] mask32;
    logic [32:0] packed_way;
    if (data_w >= 32) mask32 = 32'hffff_ffff;
    else if (data_w <= 0) mask32 = 32'd0;
    else mask32 = (32'h1 << data_w) - 1;
    packed_way = '0;
    packed_way[data_w] = valid;
    packed_way[31:0] = data & mask32;
    return packed_way;
  endfunction

endpackage
`endif
