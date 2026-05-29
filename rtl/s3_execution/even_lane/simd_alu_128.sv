// 128-bit packed SIMD ALU: VADD, VSUB, VAND, VOR, VXOR (16x8 / 8x16 / 4x32 lanes).
module simd_alu_128
  import spu_lite_pkg::*;
(
  input  vec_alu_op_e  vec_op,
  input  lane_mode_e   lane_mode,
  input  vreg_t        vs1_data,
  input  vreg_t        vs2_data,
  output vreg_t        vd_data
);

  genvar i;

  always_comb begin
    vd_data = '0;

    unique case (lane_mode)
      LANE_B: begin
        for (int k = 0; k < 16; k++) begin
          automatic logic [7:0] a = vs1_data[k*8  +: 8];
          automatic logic [7:0] b = vs2_data[k*8  +: 8];
          unique case (vec_op)
            VEC_ALU_ADD: vd_data[k*8 +: 8] = a + b;
            VEC_ALU_SUB: vd_data[k*8 +: 8] = a - b;
            VEC_ALU_AND: vd_data[k*8 +: 8] = a & b;
            VEC_ALU_OR:  vd_data[k*8 +: 8] = a | b;
            VEC_ALU_XOR: vd_data[k*8 +: 8] = a ^ b;
            default:     vd_data[k*8 +: 8] = '0;
          endcase
        end
      end

      LANE_H: begin
        for (int k = 0; k < 8; k++) begin
          automatic logic [15:0] a = vs1_data[k*16 +: 16];
          automatic logic [15:0] b = vs2_data[k*16 +: 16];
          unique case (vec_op)
            VEC_ALU_ADD: vd_data[k*16 +: 16] = a + b;
            VEC_ALU_SUB: vd_data[k*16 +: 16] = a - b;
            VEC_ALU_AND: vd_data[k*16 +: 16] = a & b;
            VEC_ALU_OR:  vd_data[k*16 +: 16] = a | b;
            VEC_ALU_XOR: vd_data[k*16 +: 16] = a ^ b;
            default:     vd_data[k*16 +: 16] = '0;
          endcase
        end
      end

      LANE_W: begin
        for (int k = 0; k < 4; k++) begin
          automatic logic [31:0] a = vs1_data[k*32 +: 32];
          automatic logic [31:0] b = vs2_data[k*32 +: 32];
          unique case (vec_op)
            VEC_ALU_ADD: vd_data[k*32 +: 32] = a + b;
            VEC_ALU_SUB: vd_data[k*32 +: 32] = a - b;
            VEC_ALU_AND: vd_data[k*32 +: 32] = a & b;
            VEC_ALU_OR:  vd_data[k*32 +: 32] = a | b;
            VEC_ALU_XOR: vd_data[k*32 +: 32] = a ^ b;
            default:     vd_data[k*32 +: 32] = '0;
          endcase
        end
      end

      default: vd_data = '0;
    endcase
  end

endmodule
