`timescale 1ns / 1ps

package memory_txn_pkg;
  import tb_pkg::*;

  function automatic memory_txn_t memory_txn_clear();
    memory_txn_clear = '0;
  endfunction

  function automatic string memory_txn_str(input memory_txn_t t);
    return $sformatf("req=%0d we=%0d addr=%08h w=%08h r=%08h rv=%0d",
                     t.req, t.we, t.addr, t.wdata, t.rdata, t.rvalid);
  endfunction
endpackage
