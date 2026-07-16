`timescale 1ns / 1ps

// Register Alias Table helpers — arch policy, branch-map columns, lookups.
package rat_pkg;

import rv_dis_pkg::*;

  // 00 = 1-col tip (map_br1). 01/10/11 = 2-col (spec + fallthrough / both).
  function automatic logic rat_one_col(input br_map_t br_map);
    return br_map == BR_MAP_NONE;
  endfunction

  function automatic logic rat_use_br0(input br_map_t br_map);
    // Spec column bit0, or keep synced in 1-col mode.
    return rat_one_col(br_map) || br_map[0];
  endfunction

  function automatic logic rat_use_br1(input br_map_t br_map);
    // Spec column bit1 / 1-col tip, or both.
    return rat_one_col(br_map) || br_map[1];
  endfunction

  // Tip column for rename reads: 01 → br0; else br1 (00 / 10 / 11).
  function automatic logic rat_tip_is_i1(input br_map_t br_map);
    return br_map != BR_MAP_I0;
  endfunction

  // x0 is hardwired zero (p0); not renameable.
  function automatic logic arch_maps_to_x0(input gpr_addr_t arch);
    return (arch == '0);
  endfunction

  function automatic prf_addr_t rat_map_read(
    input gpr_addr_t  arch,
    input logic       tip_is_i1,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    rat_map_read = tip_is_i1 ? map_br1[arch] : map_br0[arch];
  endfunction

  function automatic prf_addr_t rat_i0_src_lookup(
    input logic       use_en,
    input gpr_addr_t  arch,
    input logic       tip_is_i1,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!use_en || arch_maps_to_x0(arch))
      rat_i0_src_lookup = '0;
    else
      rat_i0_src_lookup = rat_map_read(arch, tip_is_i1, map_br0, map_br1);
  endfunction

  function automatic prf_addr_t rat_i1_src_lookup(
    input logic       use_en,
    input gpr_addr_t  arch,
    input logic       i0_rd_legal,
    input gpr_addr_t  i0_rd_addr,
    input prf_addr_t  i0_prd_new_tag,
    input logic       tip_is_i1,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!use_en || arch_maps_to_x0(arch))
      rat_i1_src_lookup = '0;
    else if (i0_rd_legal && (arch == i0_rd_addr))
      rat_i1_src_lookup = i0_prd_new_tag;
    else
      rat_i1_src_lookup = rat_map_read(arch, tip_is_i1, map_br0, map_br1);
  endfunction

endpackage
