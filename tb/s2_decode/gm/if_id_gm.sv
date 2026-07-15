`timescale 1ns / 1ps

// Golden model for rtl/s2_decode/if_id.sv
// CLEAR and per-lane miss => INSTR_NOP bubble; target_valid latched on fetch hit.
import rv_dis_pkg::*;

module if_id_gm (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,
  input  logic        stall,
  input  logic        i0_fetch_valid,
  input  logic        i1_fetch_valid,
  input  logic        i0_target_valid_if,
  input  logic        i1_target_valid_if,
  input  logic        spec0_en_if,
  input  logic        spec1_en_if,
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
  output word_t       i1_pc_target_id,
  output logic        i0_valid_id,
  output logic        i1_valid_id,
  output logic        i0_target_valid_id,
  output logic        i1_target_valid_id,
  output logic        spec0_en_id,
  output logic        spec1_en_id
);

  typedef enum logic [1:0] {
    GM_CLEAR   = 2'd0,
    GM_HOLD    = 2'd1,
    GM_CAPTURE = 2'd2
  } gm_op_e;

  localparam gm_op_e CTRL_LUT [0:15] = '{
    GM_CLEAR, GM_CLEAR, GM_CLEAR, GM_CLEAR,
    GM_CLEAR, GM_CLEAR, GM_CLEAR, GM_CLEAR,
    GM_HOLD,  GM_HOLD,  GM_CLEAR, GM_CLEAR,
    GM_CAPTURE, GM_HOLD, GM_CLEAR, GM_CLEAR
  };

  logic [3:0] ctrl;
  gm_op_e     op;

  assign ctrl = {rst_n, enable, flush, stall};
  assign op   = CTRL_LUT[ctrl];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i0_instr_id        <= INSTR_NOP;
      i1_instr_id        <= INSTR_NOP;
      i0_pc_id           <= '0;
      i1_pc_id           <= '0;
      i0_pc_target_id    <= '0;
      i1_pc_target_id    <= '0;
      i0_valid_id        <= 1'b0;
      i1_valid_id        <= 1'b0;
      i0_target_valid_id <= 1'b0;
      i1_target_valid_id <= 1'b0;
      spec0_en_id        <= 1'b0;
      spec1_en_id        <= 1'b0;
    end else begin
      unique case (op)
        GM_CLEAR: begin
          i0_instr_id        <= INSTR_NOP;
          i1_instr_id        <= INSTR_NOP;
          i0_pc_id           <= '0;
          i1_pc_id           <= '0;
          i0_pc_target_id    <= '0;
          i1_pc_target_id    <= '0;
          i0_valid_id        <= 1'b0;
          i1_valid_id        <= 1'b0;
          i0_target_valid_id <= 1'b0;
          i1_target_valid_id <= 1'b0;
          spec0_en_id        <= 1'b0;
          spec1_en_id        <= 1'b0;
        end
        GM_CAPTURE: begin
          if (i0_fetch_valid) begin
            i0_instr_id        <= i0_instr_if;
            i0_pc_id           <= i0_pc_if;
            i0_pc_target_id    <= i0_pc_target_if;
            i0_valid_id        <= 1'b1;
            i0_target_valid_id <= i0_target_valid_if;
            spec0_en_id        <= spec0_en_if;
          end else begin
            i0_instr_id        <= INSTR_NOP;
            i0_pc_id           <= '0;
            i0_pc_target_id    <= '0;
            i0_valid_id        <= 1'b0;
            i0_target_valid_id <= 1'b0;
            spec0_en_id        <= 1'b0;
          end

          if (i1_fetch_valid) begin
            i1_instr_id        <= i1_instr_if;
            i1_pc_id           <= i1_pc_if;
            i1_pc_target_id    <= i1_pc_target_if;
            i1_valid_id        <= 1'b1;
            i1_target_valid_id <= i1_target_valid_if;
            spec1_en_id        <= spec1_en_if;
          end else begin
            i1_instr_id        <= INSTR_NOP;
            i1_pc_id           <= '0;
            i1_pc_target_id    <= '0;
            i1_valid_id        <= 1'b0;
            i1_target_valid_id <= 1'b0;
            spec1_en_id        <= 1'b0;
          end
        end
        default: begin
        end
      endcase
    end
  end

endmodule
