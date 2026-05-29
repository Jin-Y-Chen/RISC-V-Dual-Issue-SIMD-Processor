// 8 x 128-bit vector register file (v0-v7).
module vector_regfile
  import spu_lite_pkg::*;
(
  input  logic             clk,
  input  logic             rst_n,
  input  logic [2:0]       raddr1,
  input  logic [2:0]       raddr2,
  input  logic [2:0]       raddr3,
  input  logic             wen,
  input  logic [2:0]       waddr,
  input  vreg_t            wdata,
  output vreg_t            rdata1,
  output vreg_t            rdata2,
  output vreg_t            rdata3
);

  vreg_t vreg [NUM_VREG];

  assign rdata1 = vreg[raddr1];
  assign rdata2 = vreg[raddr2];
  assign rdata3 = vreg[raddr3];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_VREG; i++)
        vreg[i] <= '0;
    end else if (wen) begin
      vreg[waddr] <= wdata;
    end
  end

endmodule
