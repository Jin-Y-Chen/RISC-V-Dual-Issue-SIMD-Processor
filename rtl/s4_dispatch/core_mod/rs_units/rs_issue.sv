`timescale 1ns / 1ps

// RS issue mux — drive issue/PRF ports from pick (bank way or dispatch bypass).
import rv_dis_pkg::*;
import rs_pkg::*;

module rs_issue (
  input  rs_entry_t     bank_q [RS_SETS][RS_WAYS],
  input  rs_disp_pair_t disp,
  input  rs_pick_t      pick,

  output rs_prf_rd_pair_t prf,
  output rs_iss_pair_t    iss
);

  rs_entry_t     e0, e1;
  rs_disp_insn_t dd0, dd1;

  always_comb begin
    iss = '0;
    prf = '0;
    e0  = bank_q[0][pick.sel0];
    e1  = bank_q[0][pick.sel1];
    dd0 = pick.src0_d1 ? disp.i1 : disp.i0;
    dd1 = pick.src1_d1 ? disp.i1 : disp.i0;

    if (pick.sel0_v) begin
      if (pick.src0_disp) begin
        iss.i0.valid     = 1'b1;
        iss.i0.lane_sel  = dd0.lane_sel;
        iss.i0.reg_write = dd0.reg_write;
        iss.i0.opcode    = dd0.opcode;
        iss.i0.funct3    = dd0.funct3;
        iss.i0.funct7    = dd0.funct7;
        iss.i0.ps1       = dd0.ps1;
        iss.i0.ps2       = dd0.ps2;
        iss.i0.prd       = dd0.prd;
        iss.i0.imm       = dd0.imm;
        iss.i0.pc        = dd0.pc;
        prf.i0.ps1       = dd0.ps1;
        prf.i0.ps2       = dd0.ps2;
      end else begin
        iss.i0.valid     = 1'b1;
        iss.i0.lane_sel  = e0.lane_sel;
        iss.i0.reg_write = e0.reg_write;
        iss.i0.opcode    = e0.opcode;
        iss.i0.funct3    = e0.funct3;
        iss.i0.funct7    = e0.funct7;
        iss.i0.ps1       = e0.ps1;
        iss.i0.ps2       = e0.ps2;
        iss.i0.prd       = e0.prd;
        iss.i0.imm       = e0.imm;
        iss.i0.pc        = e0.pc;
        prf.i0.ps1       = e0.ps1;
        prf.i0.ps2       = e0.ps2;
      end
    end

    if (pick.sel1_v) begin
      if (pick.src1_disp) begin
        iss.i1.valid     = 1'b1;
        iss.i1.lane_sel  = dd1.lane_sel;
        iss.i1.reg_write = dd1.reg_write;
        iss.i1.opcode    = dd1.opcode;
        iss.i1.funct3    = dd1.funct3;
        iss.i1.funct7    = dd1.funct7;
        iss.i1.ps1       = dd1.ps1;
        iss.i1.ps2       = dd1.ps2;
        iss.i1.prd       = dd1.prd;
        iss.i1.imm       = dd1.imm;
        iss.i1.pc        = dd1.pc;
        prf.i1.ps1       = dd1.ps1;
        prf.i1.ps2       = dd1.ps2;
      end else begin
        iss.i1.valid     = 1'b1;
        iss.i1.lane_sel  = e1.lane_sel;
        iss.i1.reg_write = e1.reg_write;
        iss.i1.opcode    = e1.opcode;
        iss.i1.funct3    = e1.funct3;
        iss.i1.funct7    = e1.funct7;
        iss.i1.ps1       = e1.ps1;
        iss.i1.ps2       = e1.ps2;
        iss.i1.prd       = e1.prd;
        iss.i1.imm       = e1.imm;
        iss.i1.pc        = e1.pc;
        prf.i1.ps1       = e1.ps1;
        prf.i1.ps2       = e1.ps2;
      end
    end
  end

endmodule
