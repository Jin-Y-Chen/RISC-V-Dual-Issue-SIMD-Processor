`timescale 1ns / 1ps

// 16-way prediction/cache bank — geometry lives in cache_struct_t from cache_struct_build.
// PC: set = pc[cfg.index_w+1 : cfg.way_aw+2], way = pc[cfg.way_aw+1:2] (PC[5:2] at index_w=13).
package cache_pkg;

  localparam int CACHE_WAYS   = 16;
  localparam int CACHE_WAY_AW = 4;

  // -------------------------------------------------------------------------
  // Cache structure — static geometry for one bank instance
  // -------------------------------------------------------------------------
  typedef struct packed {
    int unsigned data_w;
    int unsigned index_w;
    int unsigned set_aw;
    int unsigned way_aw;
    int unsigned sets;
    int unsigned ways;
    int unsigned entry_count;
  } cache_struct_t;

  // Usage:
  //   localparam cache_struct_t CACHE = cache_struct_build#(.DATA_W(2), .INDEX_W(13))();
  //   logic [CACHE.data_w:0] bank [CACHE.sets][CACHE.ways];
  //   bank[pc_set(pc, CACHE)][pc_way(pc, CACHE)] <= cache_bank_write#(CACHE.data_w)(1'b1, data);
  //   assign out = cache_bank_read#(CACHE.data_w, CACHE.sets)(bank, pc, CACHE, default);

  // -------------------------------------------------------------------------
  // Public — build cache structure (INDEX_W => entry_count = 2**INDEX_W)
  // -------------------------------------------------------------------------

  function automatic cache_struct_t cache_struct_build #(
    int DATA_W  = 32,
    int INDEX_W = 13
  )();
    if (INDEX_W <= CACHE_WAY_AW) begin
      $fatal(1, "cache_pkg: INDEX_W=%0d must be > CACHE_WAY_AW=%0d", INDEX_W, CACHE_WAY_AW);
    end
    cache_struct_build.data_w      = DATA_W;
    cache_struct_build.index_w     = INDEX_W;
    cache_struct_build.way_aw      = CACHE_WAY_AW;
    cache_struct_build.set_aw      = INDEX_W - CACHE_WAY_AW;
    cache_struct_build.ways        = CACHE_WAYS;
    cache_struct_build.entry_count = (1 << INDEX_W);
    cache_struct_build.sets        = cache_struct_build.entry_count / CACHE_WAYS;
  endfunction

  // -------------------------------------------------------------------------
  // Public — PC indexing (use cfg fields)
  // -------------------------------------------------------------------------

  function automatic logic [15:0] pc_set(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    return pc[cfg.index_w+1 : cfg.way_aw+2];
  endfunction

  function automatic logic [CACHE_WAY_AW-1:0] pc_way(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    return pc[cfg.way_aw+1:2];
  endfunction

  function automatic logic [15:0] pc_index(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    return pc[cfg.index_w+1:2];
  endfunction

  // -------------------------------------------------------------------------
  // Public — read / write; each entry is packed {valid, data[DATA_W-1:0]}
  // -------------------------------------------------------------------------

  // Way — one slot [DATA_W:0]
  function automatic logic [DATA_W-1:0] cache_way_read #(
    int DATA_W = 32
  )(
    input logic [DATA_W:0]   way,           // packed {valid, data}
    input logic [DATA_W-1:0] default_data   // returned when valid=0
  );
    return way[DATA_W] ? way[DATA_W-1:0] : default_data;
  endfunction

  function automatic logic [DATA_W:0] cache_way_write #(
    int DATA_W = 32
  )(
    input logic             valid,
    input logic [DATA_W-1:0] data
  );
    return {valid, data};
  endfunction

  // Set — one row bank[set_idx][0:WAYS-1]; read/write selects a way within the set
  function automatic logic [DATA_W-1:0] cache_set_read #(
    int DATA_W = 32
  )(
    input logic [DATA_W:0] set [CACHE_WAYS], // bank[set_idx] — all ways in one set
    input logic [CACHE_WAY_AW-1:0] way_idx, // which way (PC[5:2] at default geometry)
    input logic [DATA_W-1:0] default_data
  );
    return cache_way_read#(DATA_W)(set[way_idx], default_data);
  endfunction

  function automatic logic [DATA_W:0] cache_set_write #(
    int DATA_W = 32
  )(
    input logic             valid,
    input logic [DATA_W-1:0] data           // assign to bank[set_idx][way_idx]
  );
    return cache_way_write#(DATA_W)(valid, data);
  endfunction

  // Bank — full [SETS][WAYS] array; set/way derived from PC via cfg
  function automatic logic [DATA_W-1:0] cache_bank_read #(
    int DATA_W = 32,
    int SETS     = 512                      // must match cfg.sets / bank array size
  )(
    input logic [DATA_W:0] bank [SETS][CACHE_WAYS],
    input logic [31:0]       pc,
    input cache_struct_t     cfg,
    input logic [DATA_W-1:0] default_data
  );
    return cache_set_read#(DATA_W)(
      bank[pc_set(pc, cfg)],
      pc_way(pc, cfg),
      default_data
    );
  endfunction

  function automatic logic [DATA_W:0] cache_bank_write #(
    int DATA_W = 32
  )(
    input logic             valid,
    input logic [DATA_W-1:0] data           // assign to bank[pc_set(pc,cfg)][pc_way(pc,cfg)]
  );
    return cache_way_write#(DATA_W)(valid, data);
  endfunction

  // Alias for cache_way_write
  function automatic logic [DATA_W:0] cache_way_pack #(
    int DATA_W = 32
  )(
    input logic             valid,
    input logic [DATA_W-1:0] data
  );
    return cache_way_write#(DATA_W)(valid, data);
  endfunction

endpackage
