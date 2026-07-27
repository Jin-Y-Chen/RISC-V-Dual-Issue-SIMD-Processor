class rename_base_seq extends uvm_sequence #(rename_req_item);
  `uvm_object_utils(rename_base_seq)

  function new(string name = "rename_base_seq");
    super.new(name);
  endfunction

  function void set_defaults(rename_req_item t);
    t.flush = 0;
    foreach (t.lane_sel[i]) begin
      t.valid_rn[i] = 0;
      t.spec_en[i] = 0;
      t.lane_sel[i] = 0;
      t.reg_write[i] = 0;
      t.store_en[i] = 0;
      t.brch_en[i] = 0;
      t.state_valid[i] = 0;
      t.brch_state[i] = '0;
      t.rs1_use[i] = 0;
      t.rs2_use[i] = 0;
      t.opcode[i] = '0;
      t.funct3[i] = '0;
      t.funct7[i] = '0;
      t.rd[i] = '0;
      t.rs1[i] = '0;
      t.rs2[i] = '0;
      t.imm[i] = '0;
      t.pc[i] = '0;
    end
  endfunction

  task send_idle();
    rename_req_item t = rename_req_item::type_id::create("idle");
    set_defaults(t);
    start_item(t);
    finish_item(t);
  endtask
endclass

class rename_smoke_seq extends rename_base_seq;
  `uvm_object_utils(rename_smoke_seq)

  function new(string name = "rename_smoke_seq");
    super.new(name);
  endfunction

  task body();
    rename_req_item t = rename_req_item::type_id::create("dual_add");
    set_defaults(t);
    start_item(t);
    foreach (t.lane_sel[i]) begin
      t.valid_rn[i] = 1;
      t.reg_write[i] = 1;
      t.rs1_use[i] = 1;
      t.rs2_use[i] = 1;
      t.opcode[i] = OPC_OP;
      t.funct3[i] = F3_ADD_SUB;
      t.funct7[i] = '0;
      t.imm[i] = '0;
    end
    t.rd[0] = 1; t.rs1[0] = 2; t.rs2[0] = 3; t.pc[0] = 32'h100;
    t.rd[1] = 4; t.rs1[1] = 1; t.rs2[1] = 5; t.pc[1] = 32'h104;
    finish_item(t);
    repeat (5) send_idle();
  endtask
endclass

class rename_random_seq extends rename_base_seq;
  `uvm_object_utils(rename_random_seq)
  rand int unsigned num_pairs = 100;
  constraint c_count { num_pairs inside {[20:500]}; }

  function new(string name = "rename_random_seq");
    super.new(name);
  endfunction

  task body();
    for (int n = 0; n < num_pairs; n++) begin
      rename_req_item t = rename_req_item::type_id::create($sformatf("pair_%0d", n));
      start_item(t);
      if (!t.randomize() with { flush == 0; })
        `uvm_fatal(get_type_name(), "request randomization failed")
      // Keep traffic flowing predictably while randomizing dependencies.
      t.reg_write[0] = 1;
      t.reg_write[1] = 1;
      t.valid_rn[0] = 1;
      t.valid_rn[1] = 1;
      t.opcode[0] = OPC_OP;
      t.opcode[1] = OPC_OP;
      t.rs1_use[0] = 1;
      t.rs2_use[0] = 1;
      t.rs1_use[1] = 1;
      t.rs2_use[1] = 1;
      t.pc[0] = word_t'(n * 8);
      t.pc[1] = word_t'(n * 8 + 4);
      finish_item(t);
    end
    repeat (4) send_idle();
  endtask
endclass

class rename_raw_hazard_seq extends rename_base_seq;
  `uvm_object_utils(rename_raw_hazard_seq)

  function new(string name = "rename_raw_hazard_seq");
    super.new(name);
  endfunction

  task body();
    rename_req_item t = rename_req_item::type_id::create("raw_pair");
    set_defaults(t);
    start_item(t);
    foreach (t.reg_write[i]) begin
      t.valid_rn[i] = 1;
      t.reg_write[i] = 1;
      t.opcode[i] = OPC_OP;
      t.rs1_use[i] = 1;
      t.rs2_use[i] = 1;
    end
    t.rd[0] = 10; t.rs1[0] = 2;  t.rs2[0] = 3;
    t.rd[1] = 11; t.rs1[1] = 10; t.rs2[1] = 10;
    finish_item(t);
    repeat (5) send_idle();
  endtask
endclass

class rename_branch_seq extends rename_base_seq;
  `uvm_object_utils(rename_branch_seq)

  function new(string name = "rename_branch_seq");
    super.new(name);
  endfunction

  task body();
    rename_req_item t = rename_req_item::type_id::create("branch_pair");
    set_defaults(t);
    start_item(t);
    t.valid_rn[0] = 1;
    t.reg_write[0] = 0;
    t.opcode[0] = OPC_BRANCH;
    t.rs1_use[0] = 1;
    t.rs2_use[0] = 1;
    t.rs1[0] = 1;
    t.rs2[0] = 2;
    t.valid_rn[1] = 1;
    t.reg_write[1] = 1;
    t.spec_en[1] = 1; // Taken child path selected by lane-0 branch result.
    t.opcode[1] = OPC_OP;
    t.rd[1] = 8;
    t.rs1_use[1] = 1;
    t.rs2_use[1] = 1;
    t.rs1[1] = 3;
    t.rs2[1] = 4;
    finish_item(t);
    repeat (5) send_idle();
  endtask
endclass

class rename_flush_seq extends rename_base_seq;
  `uvm_object_utils(rename_flush_seq)

  function new(string name = "rename_flush_seq");
    super.new(name);
  endfunction

  task body();
    rename_req_item t = rename_req_item::type_id::create("pre_flush");
    set_defaults(t);
    start_item(t);
    foreach (t.reg_write[i]) begin
      t.valid_rn[i] = 1;
      t.reg_write[i] = 1;
      t.opcode[i] = OPC_OP;
      t.rd[i] = gpr_addr_t'(i + 1);
    end
    finish_item(t);
    send_idle();
    t = rename_req_item::type_id::create("flush");
    set_defaults(t);
    start_item(t);
    t.flush = 1;
    finish_item(t);
    repeat (4) send_idle();
  endtask
endclass

class rename_wb_base_seq extends uvm_sequence #(rename_wb_item);
  `uvm_object_utils(rename_wb_base_seq)

  function new(string name = "rename_wb_base_seq");
    super.new(name);
  endfunction

  task send_idle();
    rename_wb_item t = rename_wb_item::type_id::create("wb_idle");
    start_item(t);
    foreach (t.wback_en[i]) begin
      t.wback_en[i] = 0;
      t.rob_idx[i] = '0;
      t.branch_taken[i] = 0;
    end
    finish_item(t);
  endtask

  task send_complete(int unsigned pair, bit branch_taken = 0);
    rename_wb_item t = rename_wb_item::type_id::create("wb_complete");
    start_item(t);
    t.wback_en[0] = 1;
    t.wback_en[1] = 1;
    t.rob_idx[0] = prf_addr_t'({1'b1, 5'((pair * 2) % ROB_DEPTH)});
    t.rob_idx[1] = prf_addr_t'({1'b1, 5'((pair * 2 + 1) % ROB_DEPTH)});
    t.branch_taken[0] = branch_taken;
    t.branch_taken[1] = 0;
    finish_item(t);
  endtask
endclass

class rename_wb_smoke_seq extends rename_wb_base_seq;
  `uvm_object_utils(rename_wb_smoke_seq)

  function new(string name = "rename_wb_smoke_seq");
    super.new(name);
  endfunction

  task body();
    send_idle();
    send_complete(0);
    repeat (4) send_idle();
  endtask
endclass

class rename_wb_random_seq extends rename_wb_base_seq;
  `uvm_object_utils(rename_wb_random_seq)
  int unsigned num_pairs = 100;

  function new(string name = "rename_wb_random_seq");
    super.new(name);
  endfunction

  task body();
    send_idle();
    for (int n = 0; n < num_pairs; n++)
      send_complete(n);
    repeat (3) send_idle();
  endtask
endclass

class rename_wb_branch_seq extends rename_wb_base_seq;
  `uvm_object_utils(rename_wb_branch_seq)

  function new(string name = "rename_wb_branch_seq");
    super.new(name);
  endfunction

  task body();
    send_idle();
    send_complete(0, 1);
    repeat (4) send_idle();
  endtask
endclass

class rename_wb_flush_seq extends rename_wb_base_seq;
  `uvm_object_utils(rename_wb_flush_seq)

  function new(string name = "rename_wb_flush_seq");
    super.new(name);
  endfunction

  task body();
    send_idle();
    send_complete(0);
    repeat (5) send_idle();
  endtask
endclass
