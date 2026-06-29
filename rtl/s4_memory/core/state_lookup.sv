`timescale 1ns / 1ps

// 2-bit branch direction FSM — next state from current state + resolved outcome.
// pc_sctrl: 1 = branch/jump taken, 0 = not taken (from MEM stage).
module state_LUT
  import rv_dis_pkg::*;
(
  input  br_state_t state,
  input  logic      pc_sctrl,
  output br_state_t next_state
);

  always_comb begin
    unique case ({state, pc_sctrl})
      3'b000: next_state = 2'b00;
      3'b001: next_state = 2'b01;
      3'b010: next_state = 2'b00;
      3'b011: next_state = 2'b11;
      3'b100: next_state = 2'b00;
      3'b101: next_state = 2'b11;
      3'b110: next_state = 2'b10;
      3'b111: next_state = 2'b11;
      default: next_state = 2'b01;
    endcase
  end

endmodule
