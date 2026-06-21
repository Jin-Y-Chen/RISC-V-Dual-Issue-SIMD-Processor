`timescale 1ns / 1ps

// Branch target buffer — direct-mapped BTB for dual fetch (i0_pc / i1_pc).
// Lookup: predicted target for each fetch PC (miss => fall-through pc+4).
// Update: per-slot WB retire of a resolved branch/jump (PC + target).
module target_buffer #(
  parameter int ENTRY_COUNT = 64
) (
  // external controls
  input  logic        clk,
  input  logic        rst_n,

  // input data — fetch lookup
  input  logic [31:0] i0_pc,
  input  logic [31:0] i1_pc,

  // input data — WB retire (branch/jump resolve)
  input  logic        i0_valid_wb,
  input  logic        i1_valid_wb,
  input  logic [31:0] i0_pc_wb,
  input  logic [31:0] i1_pc_wb,
  input  logic [31:0] i0_target_wb,
  input  logic [31:0] i1_target_wb,

  // output data
  output logic [31:0] i0_pc_target,
  output logic [31:0] i1_pc_target
);

  localparam int INDEX_AW = $clog2(ENTRY_COUNT);
  localparam int TAG_MSB  = 31 - INDEX_AW - 2;

  logic                valid_q  [0:ENTRY_COUNT-1];
  logic [TAG_MSB:0]    tag_q    [0:ENTRY_COUNT-1];
  logic [31:0]         target_q [0:ENTRY_COUNT-1];

  logic [INDEX_AW-1:0] idx0;
  logic [INDEX_AW-1:0] idx1;
  logic [INDEX_AW-1:0] update_idx0;
  logic [INDEX_AW-1:0] update_idx1;

  function automatic logic [31:0] predict_target(
    input logic [31:0]      pc,
    input logic             hit_valid,
    input logic [TAG_MSB:0] hit_tag,
    input logic [31:0]      hit_target
  );
    if (hit_valid && (hit_tag == pc[31 -: TAG_MSB+1]))
      predict_target = hit_target;
    else
      predict_target = pc + 32'd4;
  endfunction

  assign idx0        = i0_pc[INDEX_AW+1:2];
  assign idx1        = i1_pc[INDEX_AW+1:2];
  assign update_idx0 = i0_pc_wb[INDEX_AW+1:2];
  assign update_idx1 = i1_pc_wb[INDEX_AW+1:2];

  assign i0_pc_target = predict_target(i0_pc, valid_q[idx0], tag_q[idx0], target_q[idx0]);
  assign i1_pc_target = predict_target(i1_pc, valid_q[idx1], tag_q[idx1], target_q[idx1]);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int e = 0; e < ENTRY_COUNT; e++) begin
        valid_q[e]  <= 1'b0;
        tag_q[e]    <= '0;
        target_q[e] <= 32'd0;
      end
    end else begin
      if (i0_valid_wb) begin
        valid_q[update_idx0]  <= 1'b1;
        tag_q[update_idx0]    <= i0_pc_wb[31 -: TAG_MSB+1];
        target_q[update_idx0] <= {i0_target_wb[31:2], 2'b00};
      end
      if (i1_valid_wb) begin
        valid_q[update_idx1]  <= 1'b1;
        tag_q[update_idx1]    <= i1_pc_wb[31 -: TAG_MSB+1];
        target_q[update_idx1] <= {i1_target_wb[31:2], 2'b00};
      end
    end
  end

endmodule
