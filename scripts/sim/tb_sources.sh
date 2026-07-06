#!/usr/bin/env bash
# Verilator source lists per testbench top (raw rtl/ + tb/).
# Usage: get_tb_sources <top>  — prints one repo-relative path per line.

get_tb_sources() {
  local top="${1:?top required}"
  case "$top" in
    pc_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s1_fetch/pc.sv tb/s1_fetch/pc_tb.sv ;;
    pc_selector_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s1_fetch/core_mod/pc_selector.sv tb/s1_fetch/pc_selector_tb.sv ;;
    instruction_cache_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv tb/s1_fetch/models/instruction_cache.sv tb/s1_fetch/instruction_cache_tb.sv ;;
    target_buffer_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv tb/s1_fetch/models/target_buffer.sv tb/s1_fetch/target_buffer_tb.sv ;;
    fetch_core_struct_tb)
      printf '%s\n' \
        rtl/common/rv_dis_pkg.sv rtl/s1_fetch/pc.sv rtl/s1_fetch/core_mod/pc_selector.sv \
        tb/s1_fetch/models/instruction_cache.sv tb/s1_fetch/models/target_buffer.sv \
        rtl/s1_fetch/fetch_core_struct.sv tb/s1_fetch/fetch_core_struct_tb.sv ;;
    if_id_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/if_id.sv tb/s2_decode/if_id_tb.sv ;;
    decoder_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/core/decode_funct/decode.sv rtl/s2_decode/core/decoder.sv tb/s2_decode/decoder_tb.sv ;;
    state_buffer_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/common/cache_pkg.sv rtl/s4_memory/branch/state_LUT.sv rtl/s2_decode/branch/state_buffer.sv tb/s2_decode/state_buffer_tb.sv ;;
    register_file_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/core/decode_funct/decode.sv rtl/s2_decode/core/decoder.sv rtl/s2_decode/core/register_file.sv tb/s2_decode/register_file_tb.sv ;;
    dispatch_hazard_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/core/decode_funct/decode.sv rtl/s2_decode/core/decoder.sv tb/s2_decode/dispatch_hazard_tb.sv ;;
    even_lane_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/core/decode_funct/decode.sv rtl/s2_decode/core/decoder.sv rtl/s3_execution/core/even_funct/scalar_alu.sv rtl/s3_execution/core/even_lane.sv tb/s3_execute/even_lane_tb.sv ;;
    odd_lane_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s2_decode/core/decode_funct/decode.sv rtl/s3_execution/core/odd_funct/branch_unit.sv rtl/s3_execution/core/odd_funct/memory_access.sv rtl/s3_execution/core/odd_lane.sv tb/s3_execute/odd_lane_tb.sv ;;
    id_ex_dispatch_tb)
      printf '%s\n' \
        rtl/common/rv_dis_pkg.sv rtl/s3_dispatch/funct_pkg/rob.sv rtl/s3_dispatch/funct_pkg/rob_queue.sv \
        rtl/s3_dispatch/funct_pkg/rob_speculate.sv rtl/s3_dispatch/funct_pkg/rob_rename.sv \
        rtl/s3_dispatch/core/reorder_buffer.sv rtl/s3_dispatch/core/branch_speculate.sv \
        rtl/s3_dispatch/core/rename_dispatch.sv rtl/s3_dispatch/dispatch_core_struct.sv tb/s3_execute/id_ex_dispatch_tb.sv ;;
    forward_unit_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s3_execution/core/forward_unit.sv tb/s3_execute/forward_unit_tb.sv ;;
    ex_mem_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s4_memory/ex_mem.sv tb/s4_memory/ex_mem_tb.sv ;;
    memory_cache_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/common/cache_pkg.sv rtl/s4_memory/core/memory_cache.sv tb/s4_memory/memory_cache_tb.sv ;;
    scoreboard_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s3_execution/dispatch_funct/scoreboard.sv tb/s3_execute/scoreboard_tb.sv ;;
    ex_mem_wb_tb)
      printf '%s\n' rtl/common/rv_dis_pkg.sv rtl/s5_wback/ex_mem_wb.sv tb/s5_wback/ex_mem_wb_tb.sv ;;
    *)
      echo "error: unsupported top: $top" >&2
      return 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  get_tb_sources "$@"
fi
