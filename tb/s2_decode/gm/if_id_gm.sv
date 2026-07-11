`timescale 1ns / 1ps

// Golden model for rtl/s2_decode/if_id.sv
// Exhaustive 4-bit control LUT — CLEAR / HOLD / CAPTURE.
//
// ctrl[3:0] = {rst_n, enable, flush, stall}
//   rst_n=0            => CLEAR (async in DUT; modeled on posedge here + async)
//   flush=1            => CLEAR (beats stall)
//   enable=1 && stall=0 => CAPTURE
//   else               => HOLD
import rv_dis_pkg::*;

module if_id_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,
  input  instr_t      i0_instr_if,
  input  instr_t      i1_instr_if,
  input  word_t       i0_pc_if,
  input  word_t       i1_pc_if,
  input  word_t       i0_pc_target_if,
  input  word_t       i1_pc_target_if,
  output instr_t      i0_instr_id,
  output instr_t      i1_instr_id,
  output word_t       i0_pc_id,
  output word_t       i1_pc_id,
  output word_t       i0_pc_target_id,
  output word_t       i1_pc_target_id
);

  typedef enum logic [1:0] {
    GM_CLEAR   = 2'd0,
    GM_HOLD    = 2'd1,
    GM_CAPTURE = 2'd2
  } gm_op_e;

  // ctrl = {rst_n, enable, flush, stall} — 16 rows
  localparam gm_op_e CTRL_LUT [0:15] = '{
    GM_CLEAR,   // 4'h0  {0,0,0,0}
    GM_CLEAR,   // 4'h1  {0,0,0,1}
    GM_CLEAR,   // 4'h2  {0,0,1,0}
    GM_CLEAR,   // 4'h3  {0,0,1,1}
    GM_CLEAR,   // 4'h4  {0,1,0,0}
    GM_CLEAR,   // 4'h5  {0,1,0,1}
    GM_CLEAR,   // 4'h6  {0,1,1,0}
    GM_CLEAR,   // 4'h7  {0,1,1,1}
    GM_HOLD,    // 4'h8  {1,0,0,0}
    GM_HOLD,    // 4'h9  {1,0,0,1}
    GM_CLEAR,   // 4'ha  {1,0,1,0}  flush
    GM_CLEAR,   // 4'hb  {1,0,1,1}  flush over stall
    GM_CAPTURE, // 4'hc  {1,1,0,0}
    GM_HOLD,    // 4'hd  {1,1,0,1}  stall
    GM_CLEAR,   // 4'he  {1,1,1,0}  flush
    GM_CLEAR    // 4'hf  {1,1,1,1}  flush over stall
  };

  logic [3:0] ctrl;
  gm_op_e     op;

  assign ctrl = {rst_n, enable, flush, stall};
  assign op   = CTRL_LUT[ctrl];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_instr_id     <= '0;
      i1_instr_id     <= '0;
      i0_pc_id        <= '0;
      i1_pc_id        <= '0;
      i0_pc_target_id <= '0;
      i1_pc_target_id <= '0;
    end else begin
      unique case (op)
        GM_CLEAR: begin
          i0_instr_id     <= '0;
          i1_instr_id     <= '0;
          i0_pc_id        <= '0;
          i1_pc_id        <= '0;
          i0_pc_target_id <= '0;
          i1_pc_target_id <= '0;
        end
        GM_CAPTURE: begin
          i0_instr_id     <= i0_instr_if;
          i1_instr_id     <= i1_instr_if;
          i0_pc_id        <= i0_pc_if;
          i1_pc_id        <= i1_pc_if;
          i0_pc_target_id <= i0_pc_target_if;
          i1_pc_target_id <= i1_pc_target_if;
        end
        default: begin
          // GM_HOLD — keep registered state
        end
      endcase
    end
  end

endmodule
