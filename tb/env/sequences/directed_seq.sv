// Hand-crafted directed stimulus (include after base_seq.sv).
class directed_seq extends base_seq;
  function new(string name = "directed_seq");
    super.new(name);
  endfunction

  virtual task body(ref tb_pkg::cpu_txn_t q[$]);
    tb_pkg::cpu_txn_t t;
    q.delete();

    t = cpu_txn_pkg::cpu_txn_clear();
    t.enable = 1'b1;
    q.push_back(t);

    t = cpu_txn_pkg::cpu_txn_clear();
    t.valid  = 1'b1;
    t.enable = 1'b1;
    t.pc0    = 32'h0000_1000;
    t.pc1    = 32'h0000_1004;
    q.push_back(t);

    t = cpu_txn_pkg::cpu_txn_clear();
    t.valid  = 1'b1;
    t.enable = 1'b1;
    t.flush  = 1'b1;
    t.pc0    = 32'h0000_2000;
    t.pc1    = 32'h0000_2004;
    q.push_back(t);

    t = cpu_txn_pkg::cpu_txn_clear();
    t.enable = 1'b1;
    t.pc0    = 32'h0000_2000;
    t.pc1    = 32'h0000_2004;
    q.push_back(t);
  endtask
endclass
