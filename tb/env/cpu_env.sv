`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;

// Top-level CPU verification environment.
module cpu_env (
  input  logic clk,
  input  logic rst_n,
  cpu_if.mon    cpu_mon_if,
  commit_if.mon cmt_mon_if,
  memory_if.drv mem_drv_if,
  memory_if.mon mem_mon_if
);
  cpu_agent u_agent (
    .cpu_mon_if (cpu_mon_if),
    .cmt_mon_if (cmt_mon_if)
  );

  memory_driver  u_mem_drv (.vif(mem_drv_if));
  memory_monitor u_mem_mon (.vif(mem_mon_if));

  cpu_scoreboard u_sb  ();
  predictor      u_pred();
endmodule
