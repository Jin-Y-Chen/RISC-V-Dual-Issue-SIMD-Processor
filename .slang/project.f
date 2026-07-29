# RV-DIS — Slang / sim file list (paths relative to repo root)
#
# Layout:
#   tb/common/     shared IF, txn, utils
#   tb/env/        full-core harness
#   tb/dpi/        DPI package + stage-grouped shims
#   tb/sN_*/tests  directed unit TBs
#   tb/sN_*/infra  stage helpers (rob_* under s3_rename; rename_core_struct is UVM-only)

+incdir+rtl/import
+incdir+tb
+incdir+tb/dpi
+incdir+tb/dpi/shims
+incdir+tb/common/interfaces
+incdir+tb/common/transactions
+incdir+tb/common/utils
+incdir+tb/common/config
+incdir+tb/env

# ---- packages ----
rtl/import/rv_dis_pkg.sv
rtl/import/cache_pkg.sv
rtl/s3_rename/funct_pkg/rob.sv
rtl/s3_rename/funct_pkg/rat.sv
rtl/s4_dispatch/funct_pkg/rs.sv
tb/dpi/dpi_pkg.sv
tb/common/utils/imem_hex_loader_pkg.sv
tb/tb_pkg.sv
tb/common/config/cpu_env_cfg.sv

# ---- common interfaces / txns ----
tb/common/interfaces/cpu_if.sv
tb/common/interfaces/commit_if.sv
tb/common/interfaces/memory_if.sv
tb/common/interfaces/irq_if.sv
tb/common/transactions/cpu_txn.sv
tb/common/transactions/commit_txn.sv
tb/common/transactions/memory_txn.sv

# ---- env (full-core) ----
tb/s1_fetch/infra/fetch_driver.sv
tb/s1_fetch/infra/fetch_monitor.sv
tb/s1_fetch/infra/fetch_agent.sv
tb/s1_fetch/infra/fetch_cov.sv
tb/env/memory_driver.sv
tb/env/memory_monitor.sv
tb/s6_wback/infra/commit_monitor.sv
tb/s6_wback/infra/arch_scoreboard.sv
tb/s6_wback/infra/arch_predictor.sv
tb/env/cpu_agent.sv
tb/env/cpu_env.sv
tb/env/cpu_test.sv
tb/tb_top.sv
tb/env/risc_dis_unit_tb.sv

# ---- RTL (DUT) ----
rtl/s2_decode/funct_pkg/decode.sv
rtl/s1_fetch/core_mod/pc.sv
rtl/s1_fetch/core_mod/pc_selector.sv
rtl/s1_fetch/core_mod/instruction_cache.sv
rtl/s1_fetch/core_mod/target_buffer.sv
rtl/s1_fetch/fetch_core_struct.sv
rtl/s2_decode/if_id.sv
rtl/s2_decode/core_mod/decoder.sv
rtl/s4_dispatch/core_mod/p_register_file.sv
rtl/s2_decode/core_mod/state_buffer.sv
rtl/s2_decode/core_mod/target_predict.sv
rtl/s2_decode/decode_core_struct.sv
rtl/s3_rename/id_rn.sv
rtl/s3_rename/core_mod/allis_table.sv
rtl/s3_rename/core_mod/reorder_buffer.sv
rtl/s3_rename/core_mod/rob_units/tail_alloc.sv
rtl/s3_rename/core_mod/rob_units/head_retire.sv
rtl/s3_rename/rename_core_struct.sv
rtl/s4_dispatch/rn_dp.sv
rtl/s4_dispatch/core_mod/rs_units/rs_wakeup.sv
rtl/s4_dispatch/core_mod/rs_units/rs_issue.sv
rtl/s4_dispatch/core_mod/rs_units/rs_alloc.sv
rtl/s4_dispatch/core_mod/reservation_station.sv
rtl/s4_dispatch/core_mod/bypass_unit.sv
rtl/s4_dispatch/core_mod/selector_unit.sv
rtl/s4_dispatch/issue_core_struct.sv
rtl/s5_execution/dp_ex.sv
rtl/s5_execution/core_mod/even_units/scalar_alu_unit.sv
rtl/s5_execution/core_mod/even_units/even_lane_struct.sv
rtl/s5_execution/core_mod/odd_units/branch_target_unit.sv
rtl/s5_execution/core_mod/odd_units/memory_address_unit.sv
rtl/s5_execution/core_mod/odd_units/odd_lane_struct.sv
rtl/s5_execution/execute_core_struct.sv
rtl/s6_memory/core/memory_cache.sv
rtl/s6_memory/core/state_lookup.sv
rtl/s6_memory/ex_mem.sv
rtl/s6_memory/memory_core_struct.sv
rtl/s7_wback/ex_mem_wb.sv
rtl/top/risc_dis_unit.sv

# ---- DPI shims (by stage) ----
tb/dpi/shims/s1_fetch/pc_gm.sv
tb/dpi/shims/s1_fetch/pc_selector_gm.sv
tb/dpi/shims/s1_fetch/instruction_cache_gm.sv
tb/dpi/shims/s1_fetch/target_buffer_gm.sv
tb/dpi/shims/s1_fetch/fetch_core_struct_gm.sv
tb/dpi/shims/s2_decode/decoder_gm.sv
tb/dpi/shims/s2_decode/if_id_gm.sv
tb/dpi/shims/s2_decode/state_buffer_gm.sv
tb/dpi/shims/s2_decode/target_predict_gm.sv
tb/dpi/shims/s3_rename/reorder_buffer_gm.sv
tb/dpi/shims/s4_dispatch/register_file_gm.sv

# ---- directed unit TBs ----
tb/s1_fetch/tests/pc_tb.sv
tb/s1_fetch/tests/pc_selector_tb.sv
tb/s1_fetch/tests/instruction_cache_tb.sv
tb/s1_fetch/tests/target_buffer_tb.sv
tb/s1_fetch/tests/fetch_core_struct_tb.sv
tb/s2_decode/tests/decoder_tb.sv
tb/s2_decode/tests/if_id_tb.sv
tb/s2_decode/tests/state_buffer_tb.sv
tb/s2_decode/tests/target_predict_tb.sv
tb/s2_decode/tests/decode_core_struct_tb.sv
tb/s3_rename/infra/rob_driver.sv
tb/s3_rename/infra/rob_monitor.sv
tb/s3_rename/infra/rob_scoreboard.sv
tb/s3_rename/tests/reorder_buffer_tb.sv
tb/s3_rename/tests/rob_tb.sv
tb/s4_dispatch/tests/rn_dp_tb.sv
tb/s4_dispatch/tests/reservation_station_tb.sv
tb/s5_execute/tests/dp_ex_tb.sv
tb/s5_execute/tests/even_lane_tb.sv
tb/s5_execute/tests/odd_lane_tb.sv
tb/s5_execute/tests/memory_cache_tb.sv
tb/s5_execute/tests/ex_mem_tb.sv
tb/s6_wback/tests/ex_mem_wb_tb.sv
