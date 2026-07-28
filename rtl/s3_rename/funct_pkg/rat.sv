`timescale 1ns / 1ps

// Register Alias Table helpers — binary path selection and same-pair bypass.
package rat_pkg;

import rv_dis_pkg::*;

  // x0 is hardwired zero (p0); not renameable.
  function automatic logic arch_maps_to_x0(input gpr_addr_t gpr_addr);
    return (gpr_addr == '0);
  endfunction

  function automatic prf_addr_t rat_map_read(
    input gpr_addr_t  gpr_addr,
    input logic       spec_en,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    // Requested mapping: spec_en=1→path1/map_br0, spec_en=0→path0/map_br1.
    rat_map_read = spec_en ? map_br0[gpr_addr] : map_br1[gpr_addr];
  endfunction

  function automatic prf_addr_t rat_src_lookup(
    input logic       rs_use,
    input gpr_addr_t  rs_addr,
    input logic       spec_en,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!rs_use || arch_maps_to_x0(rs_addr))
      rat_src_lookup = '0;
    else
      rat_src_lookup = rat_map_read(rs_addr, spec_en, map_br0, map_br1);
  endfunction

  // Operand ready: no PRF read, PRF tag ready, or blocked by same-pair RAW.
  function automatic logic rat_src_tag_ready(
    input logic               rs_use,
    input gpr_addr_t          rs_addr,
    input prf_addr_t          ps_tag,
    input logic [NUM_PRF-1:0] prf_ready,
    input logic               raw_block
  );
    if (!rs_use || arch_maps_to_x0(rs_addr))
      rat_src_tag_ready = 1'b1;
    else if (raw_block)
      rat_src_tag_ready = 1'b0;
    else
      rat_src_tag_ready = prf_ready[ps_tag];
  endfunction

  // I1 source rename with same-cycle I0 RAW bypass (alloc_* = I0 dest).
  function automatic prf_addr_t rat_i1_src_lookup(
    input logic       rs_use,
    input gpr_addr_t  rs_addr,
    input logic       alloc_en,
    input gpr_addr_t  alloc_rd_addr,
    input prf_addr_t  alloc_rob_tag,
    input logic       spec_en0,
    input logic       spec_en1,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!rs_use || arch_maps_to_x0(rs_addr))
      rat_i1_src_lookup = '0;
    else if (alloc_en && !arch_maps_to_x0(alloc_rd_addr) &&
             (spec_en0 == spec_en1) && (rs_addr == alloc_rd_addr))
      rat_i1_src_lookup = alloc_rob_tag;
    else
      rat_i1_src_lookup = rat_map_read(rs_addr, spec_en1, map_br0, map_br1);
  endfunction

endpackage
