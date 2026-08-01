`timescale 1ns / 1ps

// DPI-C imports for staged C++ golden models (model/). Package: dpi_pkg.
package dpi_pkg;

  // ---- s1: pc_selector (combo) ----
  import "DPI-C" function void pc_sel_dpi_eval(
    input int spec0_in, input int spec1_in,
    input int i0_pred_taken, input int i1_pred_taken,
    input int i0_brch_recover, input int i1_brch_recover,
    input int pc0_in, input int pc1_in,
    input int i0_pc_target, input int i1_pc_target,
    input int i0_pc_execute, input int i1_pc_execute,
    output int spec0_out, output int spec1_out,
    output int pc0_out, output int pc1_out
  );

  // ---- s1: pc (posedge) ----
  import "DPI-C" function chandle pc_dpi_create(input int reset_pc);
  import "DPI-C" function void    pc_dpi_destroy(input chandle h);
  import "DPI-C" function void    pc_dpi_reset(input chandle h);
  import "DPI-C" function void    pc_dpi_eval(
    input chandle h, output int pc0, output int pc1, output int spec0, output int spec1);
  import "DPI-C" function void    pc_dpi_commit(
    input chandle h, input int rst_n, input int enable, input int dispatch_stall,
    input int spec0_stall, input int spec1_stall, input int spec0_in, input int spec1_in,
    input int pc0_in, input int pc1_in);

  // ---- s1: instruction_cache (combo) ----
  import "DPI-C" function void icache_dpi_eval(
    input int pc0, input int pc1,
    output int instr0, output int instr1, output int v0, output int v1);

  // ---- s1: target_buffer (negedge) ----
  import "DPI-C" function chandle btb_dpi_create();
  import "DPI-C" function void    btb_dpi_destroy(input chandle h);
  import "DPI-C" function void    btb_dpi_reset(input chandle h);
  import "DPI-C" function void    btb_dpi_eval(
    input chandle h, input int i0_pc, input int i1_pc,
    input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_tgt_wb, input int i1_tgt_wb,
    output int i0_valid, output int i1_valid, output int i0_tgt, output int i1_tgt);
  import "DPI-C" function void    btb_dpi_commit(
    input chandle h, input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_tgt_wb, input int i1_tgt_wb);

  // ---- s1: fetch_core_struct ----
  import "DPI-C" function chandle fetch_dpi_create(input int reset_pc);
  import "DPI-C" function void    fetch_dpi_destroy(input chandle h);
  import "DPI-C" function void    fetch_dpi_reset(input chandle h);
  import "DPI-C" function void    fetch_dpi_eval(
    input chandle h, input int rst_n, input int enable, input int dispatch_stall,
    input int spec0_stall, input int spec1_stall,
    input int i0_pred_taken, input int i1_pred_taken,
    input int i0_brch_recover, input int i1_brch_recover,
    input int i0_pc_execute, input int i1_pc_execute,
    input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_tgt_wb, input int i1_tgt_wb,
    output int pc0, output int pc1, output int i0_tgt, output int i1_tgt,
    output int instr0, output int instr1, output int spec0, output int spec1,
    output int i0_valid, output int i1_valid, output int i0_tv, output int i1_tv);
  import "DPI-C" function void fetch_dpi_commit_posedge(
    input chandle h, input int rst_n, input int enable, input int dispatch_stall,
    input int spec0_stall, input int spec1_stall,
    input int i0_pred_taken, input int i1_pred_taken,
    input int i0_brch_recover, input int i1_brch_recover,
    input int i0_pc_execute, input int i1_pc_execute,
    input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_tgt_wb, input int i1_tgt_wb);
  import "DPI-C" function void fetch_dpi_commit_negedge(
    input chandle h, input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_tgt_wb, input int i1_tgt_wb);

  // ---- s2: decoder ----
  import "DPI-C" function void decoder_dpi_eval(
    input int instr,
    output int lane_sel, output int brch_en, output int jump_en,
    output int opcode, output int funct3, output int funct7,
    output int rd, output int rs1, output int rs2, output int imm,
    output int valid, output int rs1_use, output int rs2_use,
    output int store_en, output int reg_write);

  // ---- s2: if_id ----
  import "DPI-C" function chandle ifid_dpi_create();
  import "DPI-C" function void    ifid_dpi_destroy(input chandle h);
  import "DPI-C" function void    ifid_dpi_reset(input chandle h);
  import "DPI-C" function void    ifid_dpi_eval(
    input chandle h,
    output int i0_instr, output int i1_instr, output int i0_pc, output int i1_pc,
    output int i0_tgt, output int i1_tgt, output int i0_fv, output int i1_fv,
    output int i0_tv, output int i1_tv, output int s0, output int s1);
  import "DPI-C" function void    ifid_dpi_commit(
    input chandle h, input int rst_n, input int enable, input int flush, input int stall,
    input int i0_fv, input int i1_fv, input int i0_tv, input int i1_tv,
    input int s0, input int s1, input int i0_instr, input int i1_instr,
    input int i0_pc, input int i1_pc, input int i0_tgt, input int i1_tgt);

  // ---- s2: state_buffer ----
  import "DPI-C" function chandle sbuf_dpi_create();
  import "DPI-C" function void    sbuf_dpi_destroy(input chandle h);
  import "DPI-C" function void    sbuf_dpi_reset(input chandle h);
  import "DPI-C" function void    sbuf_dpi_eval(
    input chandle h, input int i0_pc, input int i1_pc,
    input int i0_brch_en, input int i1_brch_en,
    input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_st_wb, input int i1_st_wb,
    output int i0_st, output int i1_st, output int i0_sv, output int i1_sv);
  import "DPI-C" function void    sbuf_dpi_commit(
    input chandle h, input int i0_valid_wb, input int i1_valid_wb,
    input int i0_pc_wb, input int i1_pc_wb, input int i0_st_wb, input int i1_st_wb);

  // ---- s2: target_predict ----
  import "DPI-C" function void tpred_dpi_eval(
    input int target_valid, input int brnch_en, input int jump_en, input int spec_n,
    input int pc, input int target_state, input int imm, input int pc_target,
    output int pc_predict, output int pred_taken, output int pred_valid_wb,
    output int nest_spec_stall);

  // ---- s3: ROB ----
  import "DPI-C" function chandle rob_dpi_create();
  import "DPI-C" function void    rob_dpi_destroy(input chandle h);
  import "DPI-C" function void    rob_dpi_reset(input chandle h);
  import "DPI-C" function void rob_dpi_eval(
    input  chandle h,
    input  int flush,
    input  int alloc0_en, input int alloc1_en,
    input  int i0_reg_write, input int i1_reg_write,
    input  int i0_is_brnch, input int i1_is_brnch,
    input  int i0_is_store, input int i1_is_store,
    input  int i0_spec_en, input int i1_spec_en,
    input  int i0_state_valid, input int i1_state_valid,
    input  int i0_brch_state, input int i1_brch_state,
    input  int i0_rd_addr, input int i1_rd_addr,
    input  int wback0_en, input int wback1_en,
    input  int i0_rob_tag_wb, input int i1_rob_tag_wb,
    input  int i0_brch_taken_wb, input int i1_brch_taken_wb,
    input  int retire0_en, input int retire1_en,
    output int i0_rob_tag, output int i1_rob_tag,
    output int stall,
    output int i0_can_retire, output int i1_can_retire,
    output int rrat0_en, output int rrat1_en,
    output int i0_rd_addr_cmt, output int i1_rd_addr_cmt,
    output int i0_rob_tag_cmt, output int i1_rob_tag_cmt,
    output int rat0_en, output int rat1_en,
    output int i0_path_sel, output int i1_path_sel,
    output int stb0_en, output int stb1_en,
    output int head, output int tail, output int occ, output int active_spec
  );
  import "DPI-C" function void rob_dpi_commit(
    input chandle h,
    input int flush,
    input int alloc0_en, input int alloc1_en,
    input int i0_reg_write, input int i1_reg_write,
    input int i0_is_brnch, input int i1_is_brnch,
    input int i0_is_store, input int i1_is_store,
    input int i0_spec_en, input int i1_spec_en,
    input int i0_state_valid, input int i1_state_valid,
    input int i0_brch_state, input int i1_brch_state,
    input int i0_rd_addr, input int i1_rd_addr,
    input int wback0_en, input int wback1_en,
    input int i0_rob_tag_wb, input int i1_rob_tag_wb,
    input int i0_brch_taken_wb, input int i1_brch_taken_wb,
    input int retire0_en, input int retire1_en
  );

  // ---- s3: alias_table (RAT + RRAT) ----
  import "DPI-C" function chandle alias_dpi_create();
  import "DPI-C" function void    alias_dpi_destroy(input chandle h);
  import "DPI-C" function void    alias_dpi_reset(input chandle h);
  import "DPI-C" function void alias_dpi_eval(
    input  chandle h,
    input  int flush,
    input  int spec0, input int spec1,
    input  int rs1_use0, input int rs1_use1, input int rs2_use0, input int rs2_use1,
    input  int rs1_addr0, input int rs1_addr1, input int rs2_addr0, input int rs2_addr1,
    input  int alloc_en0, input int alloc_en1,
    input  int alloc_rd0, input int alloc_rd1,
    input  int alloc_tag0, input int alloc_tag1,
    input  int rrat_en0, input int rrat_en1,
    input  int rd_cmt0, input int rd_cmt1,
    input  int tag_cmt0, input int tag_cmt1,
    input  int rat_en0, input int rat_en1,
    input  int path_sel0, input int path_sel1,
    output int path_use0, output int path_use1,
    output int ps1_0, output int ps1_1,
    output int ps2_0, output int ps2_1
  );
  import "DPI-C" function void alias_dpi_commit(
    input chandle h,
    input int flush,
    input int spec0, input int spec1,
    input int rs1_use0, input int rs1_use1, input int rs2_use0, input int rs2_use1,
    input int rs1_addr0, input int rs1_addr1, input int rs2_addr0, input int rs2_addr1,
    input int alloc_en0, input int alloc_en1,
    input int alloc_rd0, input int alloc_rd1,
    input int alloc_tag0, input int alloc_tag1,
    input int rrat_en0, input int rrat_en1,
    input int rd_cmt0, input int rd_cmt1,
    input int tag_cmt0, input int tag_cmt1,
    input int rat_en0, input int rat_en1,
    input int path_sel0, input int path_sel1
  );

  // ---- s4: register_file ----
  import "DPI-C" function chandle rf_dpi_create();
  import "DPI-C" function void    rf_dpi_destroy(input chandle h);
  import "DPI-C" function void    rf_dpi_reset(input chandle h);
  import "DPI-C" function void    rf_dpi_eval(
    input chandle h,
    input int i0_rs1_use, input int i0_rs2_use, input int i1_rs1_use, input int i1_rs2_use,
    input int i0_valid_wb, input int i1_valid_wb,
    input int i0_rs1, input int i0_rs2, input int i1_rs1, input int i1_rs2,
    input int i0_rd, input int i1_rd, input int i0_data, input int i1_data,
    output int d00, output int d01, output int d10, output int d11);
  import "DPI-C" function void    rf_dpi_commit(
    input chandle h, input int i0_valid_wb, input int i1_valid_wb,
    input int i0_rd, input int i1_rd, input int i0_data, input int i1_data);

  // ---- full-core stub (tb/dpi/cpu_dpi.cpp) ----
  import "DPI-C" function void cpu_dpi_reset();
  import "DPI-C" function void cpu_dpi_step(input int enable, input int flush);
  import "DPI-C" function int  cpu_dpi_get_pc0();
  import "DPI-C" function int  cpu_dpi_get_pc1();

endpackage
