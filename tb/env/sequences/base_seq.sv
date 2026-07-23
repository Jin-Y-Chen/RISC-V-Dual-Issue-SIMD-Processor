`timescale 1ns / 1ps

// Virtual base sequence — subclasses override body().
// Include this file (and subclasses) from one compilation unit only (e.g. cpu_test).
class base_seq;
  string name;
  int unsigned n_items;

  function new(string name = "base_seq");
    this.name    = name;
    this.n_items = 0;
  endfunction

  virtual task body(ref tb_pkg::cpu_txn_t q[$]);
    q.delete();
  endtask

  task run(ref tb_pkg::cpu_txn_t q[$]);
    body(q);
    n_items = q.size();
  endtask
endclass
