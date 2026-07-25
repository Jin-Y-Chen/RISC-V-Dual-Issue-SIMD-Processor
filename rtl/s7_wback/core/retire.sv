`timescale 1ns / 1ps

// Retire — applies enable/flush to ROB-computed head readiness.
import rv_dis_pkg::*;
import rob_pkg::*;

module retire (
  input  logic enable,
  input  logic flush,

  input  logic i0_can_retire,
  input  logic i1_can_retire,

  output logic retire0_en,
  output logic retire1_en
);

  assign retire0_en = enable && !flush && i0_can_retire;
  assign retire1_en = enable && !flush && i1_can_retire;

endmodule
