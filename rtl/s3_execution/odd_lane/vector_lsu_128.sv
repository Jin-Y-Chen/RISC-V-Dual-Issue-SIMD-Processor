// 128-bit vector load/store address and write-data formatting (VLD128 / VST128).
module vector_lsu_128
  import spu_lite_pkg::*;
(
  input  logic        is_store,
  input  logic [31:0] base_addr,
  input  logic [31:0] imm,
  input  vreg_t       vs_data,
  output logic [31:0] mem_addr,
  output logic [15:0] mem_be,
  output vreg_t       mem_wdata,
  output logic        addr_misaligned
);

  assign mem_addr = (base_addr + imm) & 32'hFFFFFFF0;
  assign mem_be   = 16'hFFFF;
  assign mem_wdata = vs_data;
  assign addr_misaligned = ((base_addr + imm) & 32'h0000000F) != 32'h0;

endmodule
