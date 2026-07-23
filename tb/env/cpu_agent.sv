`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Bundles CPU / commit monitors (driver lives in cpu_test).
module cpu_agent (
  cpu_if.mon    cpu_mon_if,
  commit_if.mon cmt_mon_if
);
  cpu_monitor    u_mon (.vif(cpu_mon_if));
  commit_monitor u_cmt (.vif(cmt_mon_if));
endmodule
