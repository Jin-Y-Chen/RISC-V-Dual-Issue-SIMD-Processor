`timescale 1ns / 1ps

package commit_txn_pkg;
  import tb_pkg::*;

  function automatic commit_txn_t commit_txn_clear();
    commit_txn_clear = '0;
  endfunction

  function automatic string commit_txn_str(input commit_txn_t t);
    return $sformatf("rrat=%0d%0d stb=%0d%0d rat=%0d%0d rd=%0d/%0d",
                     t.rrat0_en, t.rrat1_en, t.stb0_en, t.stb1_en,
                     t.rat0_en, t.rat1_en, t.rd0, t.rd1);
  endfunction
endpackage
