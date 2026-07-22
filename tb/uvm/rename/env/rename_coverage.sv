class rename_coverage extends uvm_subscriber #(rename_req_item);
  `uvm_component_utils(rename_coverage)

  opcode_t op0, op1;
  bit path0, path1;
  bit valid0, valid1, stall, flush;
  bit raw_i1_rs1, raw_i1_rs2;

  covergroup rename_cg;
    option.per_instance = 1;

    cp_op0: coverpoint op0 {
      bins idle   = {7'b0};
      bins alu[]  = {OPC_OP, OPC_OP_IMM};
      bins memory[] = {OPC_LOAD, OPC_STORE};
      bins control[] = {OPC_BRANCH, OPC_JAL, OPC_JALR};
      bins upper[] = {OPC_AUIPC, OPC_LUI};
    }
    cp_op1: coverpoint op1 {
      bins idle   = {7'b0};
      bins alu[]  = {OPC_OP, OPC_OP_IMM};
      bins memory[] = {OPC_LOAD, OPC_STORE};
      bins control[] = {OPC_BRANCH, OPC_JAL, OPC_JALR};
      bins upper[] = {OPC_AUIPC, OPC_LUI};
    }
    cp_issue: coverpoint {valid1, valid0} {
      bins none = {2'b00};
      bins lane0 = {2'b01};
      bins lane1 = {2'b10};
      bins dual = {2'b11};
    }
    cp_paths: coverpoint {path1, path0} {
      bins both_path0 = {2'b00};
      bins split_10   = {2'b01};
      bins split_01   = {2'b10};
      bins both_path1 = {2'b11};
    }
    cp_raw_rs1: coverpoint raw_i1_rs1;
    cp_raw_rs2: coverpoint raw_i1_rs2;
    cp_stall: coverpoint stall;
    cp_flush: coverpoint flush;
    cross_issue_op: cross cp_issue, cp_op0, cp_op1;
    cross_hazard: cross cp_raw_rs1, cp_raw_rs2, cp_issue;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    rename_cg = new();
  endfunction

  function void write(rename_req_item t);
    op0 = t.opcode[0];
    op1 = t.opcode[1];
    path0 = t.spec_en[0];
    path1 = t.spec_en[1];
    valid0 = t.valid[0];
    valid1 = t.valid[1];
    stall = t.stall;
    flush = t.flush;
    raw_i1_rs1 = t.reg_write[0] && t.rd[0] != '0 &&
                 t.rs1_use[1] && t.rs1[1] == t.rd[0];
    raw_i1_rs2 = t.reg_write[0] && t.rd[0] != '0 &&
                 t.rs2_use[1] && t.rs2[1] == t.rd[0];
    rename_cg.sample();
  endfunction
endclass
