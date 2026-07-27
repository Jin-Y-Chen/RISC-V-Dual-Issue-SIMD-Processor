interface rename_if(input logic clk);
  import rv_dis_pkg::*;

  logic      rst_n;
  logic      flush;

  logic      spec_en_rn      [2];
  logic      valid_rn        [2];
  logic      reg_write_rn    [2];
  logic      store_en_rn     [2];
  logic      brch_en_rn      [2];
  logic      state_valid_rn  [2];
  br_state_t brch_state_rn   [2];
  logic      rs1_use_rn      [2];
  logic      rs2_use_rn      [2];
  gpr_addr_t rd_addr_rn      [2];
  gpr_addr_t rs1_addr_rn     [2];
  gpr_addr_t rs2_addr_rn     [2];

  logic      wback_en        [2];
  prf_addr_t rob_idx_wb      [2];
  logic      brch_taken_wb   [2];

  logic      stall;
  logic      valid_rs        [2];
  logic      spec_en_rs      [2];
  prf_addr_t ps1_rs          [2];
  prf_addr_t ps2_rs          [2];
  logic      tag1_valid_rs   [2];
  logic      tag2_valid_rs   [2];
  prf_addr_t prd_rs          [2];

  // The monitor samples the completed cycle just before negedge. Drivers then
  // launch the next transaction, which remains stable through the next posedge.
  clocking req_drv_cb @(negedge clk);
    default input #1step output #0;
    output flush, spec_en_rn, valid_rn, reg_write_rn, store_en_rn;
    output brch_en_rn, state_valid_rn, brch_state_rn;
    output rs1_use_rn, rs2_use_rn;
    output rd_addr_rn, rs1_addr_rn, rs2_addr_rn;
  endclocking

  clocking wb_drv_cb @(negedge clk);
    default input #1step output #0;
    output wback_en, rob_idx_wb, brch_taken_wb;
  endclocking

  clocking mon_cb @(negedge clk);
    default input #1step;
    input rst_n, flush, spec_en_rn, valid_rn, reg_write_rn;
    input store_en_rn, brch_en_rn, state_valid_rn, brch_state_rn;
    input rs1_use_rn, rs2_use_rn;
    input rd_addr_rn, rs1_addr_rn, rs2_addr_rn;
    input wback_en, rob_idx_wb, brch_taken_wb;
    input stall;
    input valid_rs, spec_en_rs;
    input ps1_rs, ps2_rs, prd_rs;
    input tag1_valid_rs, tag2_valid_rs;
  endclocking

  modport req_driver(clocking req_drv_cb, input rst_n);
  modport wb_driver(clocking wb_drv_cb, input rst_n);
  modport monitor(clocking mon_cb);
endinterface
