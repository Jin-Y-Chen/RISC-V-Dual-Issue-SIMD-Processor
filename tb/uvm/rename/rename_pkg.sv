package rename_uvm_pkg;
  import uvm_pkg::*;
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rv_base_pkg::*;
  `include "uvm_macros.svh"

  `include "agents/rename_req_agent.sv"
  `include "agents/rename_wb_agent.sv"
  `include "env/rename_refmodel.sv"
  `include "env/rename_scoreboard.sv"
  `include "env/rename_coverage.sv"
  `include "env/rename_env_cfg.sv"
  `include "env/rename_env.sv"
  `include "seq/rename_sequences.sv"
  `include "test/rename_tests.sv"
endpackage
