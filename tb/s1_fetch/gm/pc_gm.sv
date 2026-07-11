`timescale 1ns / 1ps

// Golden model for rtl/s1_fetch/pc.sv
// Exhaustive 6-bit control LUT - one explicit table row per ctrl[5:0].
//
// ctrl[5:0] = {rst_n, enable, fetch_stall, dispatch_stall, mode, spec0_en}
//   rst_n          - 0 => RESET regardless of other inputs
//   enable         - 0 => HOLD (when rst_n=1)
//   fetch_stall    - 1 => HOLD (when rst_n=1, enable=1)
//   dispatch_stall - 1 => HOLD (when rst_n=1, enable=1)
//   mode           - 0 => ADV8 at 6'h30-31, ADV4 at 6'h32-33; 1 => HOLD
//   spec0_en       - is_spec on ADV4/ADV8 rows only
//
// State advances on posedge clk, matching pc.sv.

module pc_gm #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        fetch_stall,
  input  logic        dispatch_stall,
  input  logic        mode,
  input  logic        spec0_en,
  input  logic [31:0] pc0_in,
  input  logic [31:0] pc1_in,
  output logic [31:0] pc0_out,
  output logic [31:0] pc1_out,
  output logic        is_spec
);

  typedef enum logic [1:0] {
    GM_RESET = 2'd0,
    GM_HOLD  = 2'd1,
    GM_ADV4  = 2'd2,
    GM_ADV8  = 2'd3
  } gm_op_e;

  typedef struct packed {
    gm_op_e op;
    logic   is_spec;
  } gm_lut_row_t;

  // -------------------------------------------------------------------------
  // CTRL_LUT[ctrl] - 64 rows, index = packed control bus (all 2^6 inputs).
  // Comment format: 6'hNN  {rst_n,en,fetch_stall,dispatch_stall,mode,spec0_en}
  // -------------------------------------------------------------------------
  localparam gm_lut_row_t CTRL_LUT [0:63] = '{
    '{GM_RESET, 1'b0}, // 6'h00  {0,0,0,0,0,0}
    '{GM_RESET, 1'b0}, // 6'h01  {0,0,0,0,0,1}
    '{GM_RESET, 1'b0}, // 6'h02  {0,0,0,0,1,0}
    '{GM_RESET, 1'b0}, // 6'h03  {0,0,0,0,1,1}
    '{GM_RESET, 1'b0}, // 6'h04  {0,0,0,1,0,0}
    '{GM_RESET, 1'b0}, // 6'h05  {0,0,0,1,0,1}
    '{GM_RESET, 1'b0}, // 6'h06  {0,0,0,1,1,0}
    '{GM_RESET, 1'b0}, // 6'h07  {0,0,0,1,1,1}
    '{GM_RESET, 1'b0}, // 6'h08  {0,0,1,0,0,0}
    '{GM_RESET, 1'b0}, // 6'h09  {0,0,1,0,0,1}
    '{GM_RESET, 1'b0}, // 6'h0a  {0,0,1,0,1,0}
    '{GM_RESET, 1'b0}, // 6'h0b  {0,0,1,0,1,1}
    '{GM_RESET, 1'b0}, // 6'h0c  {0,0,1,1,0,0}
    '{GM_RESET, 1'b0}, // 6'h0d  {0,0,1,1,0,1}
    '{GM_RESET, 1'b0}, // 6'h0e  {0,0,1,1,1,0}
    '{GM_RESET, 1'b0}, // 6'h0f  {0,0,1,1,1,1}
    '{GM_RESET, 1'b0}, // 6'h10  {0,1,0,0,0,0}
    '{GM_RESET, 1'b0}, // 6'h11  {0,1,0,0,0,1}
    '{GM_RESET, 1'b0}, // 6'h12  {0,1,0,0,1,0}
    '{GM_RESET, 1'b0}, // 6'h13  {0,1,0,0,1,1}
    '{GM_RESET, 1'b0}, // 6'h14  {0,1,0,1,0,0}
    '{GM_RESET, 1'b0}, // 6'h15  {0,1,0,1,0,1}
    '{GM_RESET, 1'b0}, // 6'h16  {0,1,0,1,1,0}
    '{GM_RESET, 1'b0}, // 6'h17  {0,1,0,1,1,1}
    '{GM_RESET, 1'b0}, // 6'h18  {0,1,1,0,0,0}
    '{GM_RESET, 1'b0}, // 6'h19  {0,1,1,0,0,1}
    '{GM_RESET, 1'b0}, // 6'h1a  {0,1,1,0,1,0}
    '{GM_RESET, 1'b0}, // 6'h1b  {0,1,1,0,1,1}
    '{GM_RESET, 1'b0}, // 6'h1c  {0,1,1,1,0,0}
    '{GM_RESET, 1'b0}, // 6'h1d  {0,1,1,1,0,1}
    '{GM_RESET, 1'b0}, // 6'h1e  {0,1,1,1,1,0}
    '{GM_RESET, 1'b0}, // 6'h1f  {0,1,1,1,1,1}
    '{GM_HOLD,  1'b0}, // 6'h20  {1,0,0,0,0,0}
    '{GM_HOLD,  1'b0}, // 6'h21  {1,0,0,0,0,1}
    '{GM_HOLD,  1'b0}, // 6'h22  {1,0,0,0,1,0}
    '{GM_HOLD,  1'b0}, // 6'h23  {1,0,0,0,1,1}
    '{GM_HOLD,  1'b0}, // 6'h24  {1,0,0,1,0,0}
    '{GM_HOLD,  1'b0}, // 6'h25  {1,0,0,1,0,1}
    '{GM_HOLD,  1'b0}, // 6'h26  {1,0,0,1,1,0}
    '{GM_HOLD,  1'b0}, // 6'h27  {1,0,0,1,1,1}
    '{GM_HOLD,  1'b0}, // 6'h28  {1,0,1,0,0,0}
    '{GM_HOLD,  1'b0}, // 6'h29  {1,0,1,0,0,1}
    '{GM_HOLD,  1'b0}, // 6'h2a  {1,0,1,0,1,0}
    '{GM_HOLD,  1'b0}, // 6'h2b  {1,0,1,0,1,1}
    '{GM_HOLD,  1'b0}, // 6'h2c  {1,0,1,1,0,0}
    '{GM_HOLD,  1'b0}, // 6'h2d  {1,0,1,1,0,1}
    '{GM_HOLD,  1'b0}, // 6'h2e  {1,0,1,1,1,0}
    '{GM_HOLD,  1'b0}, // 6'h2f  {1,0,1,1,1,1}
    '{GM_ADV8,  1'b0}, // 6'h30  {1,1,0,0,0,0}
    '{GM_ADV8,  1'b1}, // 6'h31  {1,1,0,0,0,1}
    '{GM_ADV4,  1'b0}, // 6'h32  {1,1,0,0,1,0}
    '{GM_ADV4,  1'b1}, // 6'h33  {1,1,0,0,1,1}
    '{GM_HOLD,  1'b0}, // 6'h34  {1,1,0,1,0,0}
    '{GM_HOLD,  1'b0}, // 6'h35  {1,1,0,1,0,1}
    '{GM_HOLD,  1'b0}, // 6'h36  {1,1,0,1,1,0}
    '{GM_HOLD,  1'b0}, // 6'h37  {1,1,0,1,1,1}
    '{GM_HOLD,  1'b0}, // 6'h38  {1,1,1,0,0,0}
    '{GM_HOLD,  1'b0}, // 6'h39  {1,1,1,0,0,1}
    '{GM_HOLD,  1'b0}, // 6'h3a  {1,1,1,0,1,0}
    '{GM_HOLD,  1'b0}, // 6'h3b  {1,1,1,0,1,1}
    '{GM_HOLD,  1'b0}, // 6'h3c  {1,1,1,1,0,0}
    '{GM_HOLD,  1'b0}, // 6'h3d  {1,1,1,1,0,1}
    '{GM_HOLD,  1'b0}, // 6'h3e  {1,1,1,1,1,0}
    '{GM_HOLD,  1'b0}  // 6'h3f  {1,1,1,1,1,1}
  };

  logic [5:0]  ctrl;
  gm_lut_row_t lut_row;
  logic [31:0] aligned_pc0;
  logic [31:0] aligned_pc1;

  assign ctrl        = {rst_n, enable, fetch_stall, dispatch_stall, mode, spec0_en};
  assign lut_row     = CTRL_LUT[ctrl];
  assign aligned_pc0 = pc0_in & ~32'd3;
  assign aligned_pc1 = pc1_in & ~32'd3;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc0_out <= RESET_PC;
      pc1_out <= RESET_PC + 32'd4;
      is_spec <= 1'b0;
    end else begin
      unique case (lut_row.op)
        GM_HOLD: begin
          // keep registered state
        end
        GM_ADV4: begin
          pc0_out <= aligned_pc0 + 32'd4;
          pc1_out <= aligned_pc1 + 32'd4;
          is_spec <= lut_row.is_spec;
        end
        GM_ADV8: begin
          pc0_out <= aligned_pc0 + 32'd8;
          pc1_out <= aligned_pc1 + 32'd8;
          is_spec <= lut_row.is_spec;
        end
        default: begin
          // GM_RESET rows apply only when rst_n=0 (handled above)
        end
      endcase
    end
  end

endmodule
