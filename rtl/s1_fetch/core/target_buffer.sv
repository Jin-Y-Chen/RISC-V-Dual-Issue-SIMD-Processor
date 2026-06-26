`timescale 1ns / 1ps

// Branch target buffer — combinational storage (mirrors state_buffer style).
// 8192 entries over 32 KiB I$ (PC[14:2]); 512 sets × 16 ways via cache_pkg.
// Lookup and WB update in the same cycle; miss (valid=0) => fallthrough(pc) = pc+4.
module target_buffer
  import rv_dis_pkg::*;
  import cache_pkg::*;
#(
  parameter int INDEX_W = 13,
  parameter int DATA_W  = 32
) (
  input  pc_t    i0_pc,
  input  pc_t    i1_pc,

  input  logic   i0_valid_wb,
  input  logic   i1_valid_wb,
  input  pc_t    i0_pc_wb,
  input  pc_t    i1_pc_wb,
  input  pc_t    i0_target_wb,
  input  pc_t    i1_target_wb,

  output pc_t    i0_pc_target,
  output pc_t    i1_pc_target
);

  localparam cache_struct_t CACHE = cache_struct_build#(.DATA_W(DATA_W), .INDEX_W(INDEX_W))();

  logic [DATA_W:0] bank [CACHE.sets][CACHE.ways];

  function automatic pc_t fallthrough(input pc_t pc);
    return pc + pc_t'(32'd4);
  endfunction

  assign i0_pc_target = pc_t'(cache_set_read#(.DATA_W(DATA_W), .WAYS(CACHE.ways))(
    bank[pc_set(i0_pc, CACHE)],
    pc_way(i0_pc, CACHE),
    fallthrough(i0_pc)
  ));

  assign i1_pc_target = pc_t'(cache_set_read#(.DATA_W(DATA_W), .WAYS(CACHE.ways))(
    bank[pc_set(i1_pc, CACHE)],
    pc_way(i1_pc, CACHE),
    fallthrough(i1_pc)
  ));

  initial begin
    for (int s = 0; s < CACHE.sets; s++) begin
      for (int w = 0; w < CACHE.ways; w++) begin
        bank[s][w] = '0;
      end
    end
  end

  always_comb begin
    if (i0_valid_wb) begin
      bank[pc_set(i0_pc_wb, CACHE)][pc_way(i0_pc_wb, CACHE)] =
        cache_set_write#(DATA_W)(1'b1, imm_align4(i0_target_wb));
    end
    if (i1_valid_wb) begin
      bank[pc_set(i1_pc_wb, CACHE)][pc_way(i1_pc_wb, CACHE)] =
        cache_set_write#(DATA_W)(1'b1, imm_align4(i1_target_wb));
    end
  end

endmodule
