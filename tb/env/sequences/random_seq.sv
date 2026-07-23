// Randomized CPU stimulus sequence (include after base_seq.sv).
class random_seq extends base_seq;
  int unsigned n_cycles;

  function new(string name = "random_seq", int unsigned n_cycles = 100);
    super.new(name);
    this.n_cycles = n_cycles;
  endfunction

  virtual task body(ref tb_pkg::cpu_txn_t q[$]);
    tb_pkg::cpu_txn_t t;
    q.delete();
    for (int i = 0; i < int'(n_cycles); i++) begin
      t = cpu_txn_pkg::cpu_txn_clear();
      t.valid  = 1'b1;
      t.enable = 1'b1;
      t.flush  = ($urandom_range(0, 99) < 2);
      t.pc0    = rv_dis_pkg::word_t'($urandom() & ~32'h3);
      t.pc1    = t.pc0 + 32'd4;
      q.push_back(t);
    end
  endtask
endclass
