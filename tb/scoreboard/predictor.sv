`timescale 1ns / 1ps

import rv_dis_pkg::*;
import tb_pkg::*;
import cpu_txn_pkg::*;
import commit_txn_pkg::*;

// Architectural predictor / reference stub for cpu_scoreboard.
// Stage GMs (model/) remain the cycle-accurate golden sources;
// this module tracks expected commit side-effects at CPU TB level.
module predictor;
  commit_txn_t exp_q [$];

  function automatic void reset();
    exp_q.delete();
  endfunction

  function automatic void push_expect(input commit_txn_t e);
    exp_q.push_back(e);
  endfunction

  function automatic bit try_pop(output commit_txn_t e);
    if (exp_q.size() == 0) begin
      e = commit_txn_clear();
      return 1'b0;
    end
    e = exp_q.pop_front();
    return 1'b1;
  endfunction

  // Placeholder: derive expected commit from a renamed instruction stream.
  function automatic commit_txn_t predict_from_cpu(input cpu_txn_t t);
    commit_txn_t e;
    e = commit_txn_clear();
    // Fill when full-CPU reference is wired; returns idle commit for now.
    if (t.valid) begin end  // silence unused until predictor is wired
    return e;
  endfunction

  initial reset();
endmodule
