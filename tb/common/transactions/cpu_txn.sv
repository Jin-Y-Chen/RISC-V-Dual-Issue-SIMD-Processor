`timescale 1ns / 1ps

// CPU front-end transaction helpers (uses tb_pkg::cpu_txn_t).
package cpu_txn_pkg;
  import tb_pkg::*;

  function automatic cpu_txn_t cpu_txn_clear();
    cpu_txn_clear = '0;
  endfunction

  function automatic string cpu_txn_str(input cpu_txn_t t);
    return $sformatf("v=%0d flush=%0d en=%0d pc0=%08h pc1=%08h",
                     t.valid, t.flush, t.enable, t.pc0, t.pc1);
  endfunction
endpackage
