// RV-DIS RTL filelist — packages first, then modules (Verilog-HDL project index).
+incdir+rtl/common
+incdir+tb/common
+incdir+tb/s1_fetch

// Packages
rtl/common/rv_dis_pkg.sv
rtl/common/cache_pkg.sv
rtl/s2_decode/funct_pkg/decode.sv
rtl/s3_dispatch/funct_pkg/rob.sv
rtl/s3_dispatch/funct_pkg/rob_speculate.sv
rtl/s3_dispatch/funct_pkg/rob_rename.sv
rtl/s3_dispatch/funct_pkg/rob_queue.sv

// S1 fetch
rtl/s1_fetch/pc.sv
rtl/s1_fetch/core_mod/pc_selector.sv
rtl/s1_fetch/core_mod/instruction_cache.sv
rtl/s1_fetch/core_mod/target_buffer.sv
rtl/s1_fetch/fetch_core_struct.sv

// S2 decode
rtl/s2_decode/if_id.sv
rtl/s2_decode/core_mod/decoder.sv
rtl/s2_decode/core_mod/register_file.sv
rtl/s2_decode/core_mod/brch_predict_units/state_buffer.sv
rtl/s2_decode/core_mod/brch_predict_units/target_predict.sv
rtl/s2_decode/decode_core_struct.sv

// S3 dispatch
rtl/s3_dispatch/id_dp.sv
rtl/s3_dispatch/core/scoreboard.sv
rtl/s3_dispatch/core/branch_speculate.sv
rtl/s3_dispatch/core/rename_dispatch.sv
rtl/s3_dispatch/core/reorder_buffer.sv
rtl/s3_dispatch/dispatch_core_struct.sv

// S4 execute
rtl/s4_execution/dp_ex.sv
rtl/s4_execution/core_mod/reservation_station.sv
rtl/s4_execution/core_mod/forward_unit.sv
rtl/s4_execution/core_mod/even_units/scalar_alu_unit.sv
rtl/s4_execution/core_mod/even_units/even_lane_struct.sv
rtl/s4_execution/core_mod/odd_units/branch_target_unit.sv
rtl/s4_execution/core_mod/odd_units/memory_address_unit.sv
rtl/s4_execution/core_mod/odd_units/odd_lane_struct.sv
rtl/s4_execution/execute_core_struct.sv

// S5 memory
rtl/s5_memory/ex_mem.sv
rtl/s5_memory/core/memory_cache.sv
rtl/s5_memory/core/state_lookup.sv
rtl/s5_memory/memory_core_struct.sv

// S6 writeback
rtl/s6_wback/ex_mem_wb.sv
rtl/s6_wback/core/retire.sv

// Top
rtl/top/risc_dis_unit.sv
