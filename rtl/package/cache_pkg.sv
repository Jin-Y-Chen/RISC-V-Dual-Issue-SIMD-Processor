`timescale 1ns / 1ps

// Set-associative prediction/cache bank — geometry lives in cache_struct_t from cache_struct_build.
// WAYS: power of 2, 1 (direct-mapped) .. 16; PC: set = pc[index_w+1 : way_aw+2], way = pc[way_aw+1:2].
package cache_pkg;

  localparam int CACHE_WAYS_MIN = 1;
  localparam int CACHE_WAYS_MAX = 16;

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
  //   localparam cache_struct_t CACHE = cache_struct_build#(.DATA_W(2), .INDEX_W(13), .WAYS(16))();
  //   logic [CACHE.data_w:0] bank [CACHE.sets][CACHE.ways];
  //   bank[pc_set(pc, CACHE)][pc_way(pc, CACHE)] <= cache_set_write#(CACHE.data_w)(1'b1, data);
  //   assign out = cache_set_read#(.DATA_W(CACHE.data_w), .WAYS(CACHE.ways))(
  //       bank[pc_set(pc, CACHE)], pc_way(pc, CACHE), default);

  // -------------------------------------------------------------------------
  // Public — build cache structure (INDEX_W => entry_count = 2**INDEX_W)
  // -------------------------------------------------------------------------

  function automatic cache_struct_t cache_struct_build #(
    int DATA_W  = 32,
    int INDEX_W = 13,
    int WAYS    = 16
  )();
    int unsigned way_aw;
    if (WAYS < CACHE_WAYS_MIN) begin
      $fatal(1, "cache_pkg: WAYS=%0d must be >= %0d", WAYS, CACHE_WAYS_MIN);
    end
    if (WAYS > CACHE_WAYS_MAX) begin
      $fatal(1, "cache_pkg: WAYS=%0d must be <= %0d", WAYS, CACHE_WAYS_MAX);
    end
    if ((WAYS & (WAYS - 1)) != 0) begin
      $fatal(1, "cache_pkg: WAYS=%0d must be a power of 2", WAYS);
    end
    way_aw = $clog2(WAYS);
    if (INDEX_W < way_aw) begin
      $fatal(1, "cache_pkg: INDEX_W=%0d must be >= way_aw=%0d (WAYS=%0d)",
             INDEX_W, way_aw, WAYS);
    end
    cache_struct_build.data_w      = DATA_W;
    cache_struct_build.index_w     = INDEX_W;
    cache_struct_build.way_aw      = way_aw;
    cache_struct_build.set_aw      = INDEX_W - way_aw;
    cache_struct_build.ways        = WAYS;
    cache_struct_build.entry_count = (1 << INDEX_W);
    cache_struct_build.sets        = cache_struct_build.entry_count / WAYS;
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

  function automatic logic [15:0] pc_way(
    input logic [31:0]   pc,
    input cache_struct_t cfg
  );
    logic [15:0] raw;
    raw = pc[cfg.way_aw+1:2];
    return raw & ({16{cfg.way_aw > 0}});
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
    int DATA_W = 32,
    int WAYS   = 16
  )(
    input logic [DATA_W:0] set [WAYS], // bank[set_idx] — all ways in one set
    input logic [15:0]     way_idx,    // pc_way(pc, cfg); unused when WAYS==1
    input logic [DATA_W-1:0] default_data
  );
    if (WAYS == 1)
      return cache_way_read#(DATA_W)(set[0], default_data);
    return cache_way_read#(DATA_W)(set[way_idx[$clog2(WAYS)-1:0]], default_data);
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
//   function automatic logic [DATA_W-1:0] cache_bank_read #(
//     int DATA_W = 32,
//     int SETS   = 512,
//     int WAYS   = 16
//   )(
//     input logic [DATA_W:0] bank [SETS][WAYS],
//     input logic [31:0]       pc,
//     input cache_struct_t     cfg,
//     input logic [DATA_W-1:0] default_data
//   );
//     return cache_set_read#(.DATA_W(DATA_W), .WAYS(WAYS))(
//       bank[pc_set(pc, cfg)],
//       pc_way(pc, cfg),
//       default_data
//     );
//   endfunction

//   function automatic logic [DATA_W:0] cache_bank_write #(
//     int DATA_W = 32
//   )(
//     input logic             valid,
//     input logic [DATA_W-1:0] data           // assign to bank[pc_set(pc,cfg)][pc_way(pc,cfg)]
//   );
//     return cache_way_write#(DATA_W)(valid, data);
//   endfunction

//   // Alias for cache_way_write
//   function automatic logic [DATA_W:0] cache_way_pack #(
//     int DATA_W = 32
//   )(
//     input logic             valid,
//     input logic [DATA_W-1:0] data
//   );
//     return cache_way_write#(DATA_W)(valid, data);
//   endfunction

endpackage
