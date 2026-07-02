`timescale 1ns / 1ps

// Register rename + dispatch routing — ROB read -> renamed EX packets -> ev/od lanes.
module rename_dispatch
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_queue_pkg::*;
  import rob_rename_pkg::*;

(
  input  logic [ROB_DATA_W:0] bank [ROB_WAYS],
  input  gpr_addr_t           tag  [ROB_WAYS],
  input  rob_ptr_t            commit_ptr,
  input  rob_ptr_t            write_ptr,

  input  logic [ROB_AW-1:0] read_idx0,
  input  logic [ROB_AW-1:0] read_idx1,
  input  logic              disp0,
  input  logic              disp1,

  output EX_packet_t rob_head0,
  output EX_packet_t rob_head1,
  output EX_packet_t i0_out,
  output EX_packet_t i1_out,
  output EX_packet_t ev0_pkt,
  output EX_packet_t ev1_pkt,
  output EX_packet_t od0_pkt,
  output EX_packet_t od1_pkt,
  output logic       i0_reg_write,
  output logic       i1_reg_write
);

  EX_packet_t rob_head0_raw;
  EX_packet_t rob_head1_raw;

  assign rob_head0_raw = rob_cache_read_ex(bank[read_idx0], tag[read_idx0]);
  assign rob_head1_raw = rob_cache_read_ex(bank[read_idx1], tag[read_idx1]);

  assign rob_head0 = rob_apply_forward(
    rob_head0_raw, tag, bank, commit_ptr, write_ptr
  );
  assign rob_head1 = rob_apply_forward(
    rob_head1_raw, tag, bank, commit_ptr, write_ptr
  );

  assign i0_out = EX_packet_if(disp0 && rob_head0.valid, rob_head0);
  assign i1_out = EX_packet_if(disp1 && rob_head1.valid, rob_head1);

  assign ev0_pkt = ex_packet_route_even(disp0, rob_head0);
  assign od0_pkt = ex_packet_route_odd(disp0, rob_head0);
  assign ev1_pkt = ex_packet_route_even(disp1, rob_head1);
  assign od1_pkt = ex_packet_route_odd(disp1, rob_head1);

  assign i0_reg_write = ex_packet_reg_write(disp0, rob_head0);
  assign i1_reg_write = ex_packet_reg_write(disp1, rob_head1);

endmodule
