`timescale 1ns / 1ps

// Register Alias Table helpers — binary path selection and same-pair bypass.
package rat_pkg;

import rv_dis_pkg::*;

  // x0 is hardwired zero (p0); not renameable.
  function automatic logic arch_maps_to_x0(input gpr_addr_t arch);
    return (arch == '0);
  endfunction

  function automatic prf_addr_t rat_map_read(
    input gpr_addr_t  arch,
    input logic       spec_en,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    // Requested mapping: spec_en=1→path1/map_br0, spec_en=0→path0/map_br1.
    rat_map_read = spec_en ? map_br0[arch] : map_br1[arch];
  endfunction

  function automatic prf_addr_t rat_src_lookup(
    input logic       use_en,
    input gpr_addr_t  arch,
    input logic       spec_en,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!use_en || arch_maps_to_x0(arch))
      rat_src_lookup = '0;
    else
      rat_src_lookup = rat_map_read(arch, spec_en, map_br0, map_br1);
  endfunction

  function automatic prf_addr_t rat_i1_src_lookup(
    input logic       use_en,
    input gpr_addr_t  arch,
    input logic       i0_rd_legal,
    input gpr_addr_t  i0_rd_addr,
    input prf_addr_t  i0_prd_new_tag,
    input logic       spec0_en,
    input logic       spec1_en,
    input prf_addr_t  map_br0 [NUM_GPR],
    input prf_addr_t  map_br1 [NUM_GPR]
  );
    if (!use_en || arch_maps_to_x0(arch))
      rat_i1_src_lookup = '0;
    else if (i0_rd_legal && (spec0_en == spec1_en) &&
             (arch == i0_rd_addr))
      rat_i1_src_lookup = i0_prd_new_tag;
    else
      rat_i1_src_lookup = rat_map_read(arch, spec1_en, map_br0, map_br1);
  endfunction

endpackage
