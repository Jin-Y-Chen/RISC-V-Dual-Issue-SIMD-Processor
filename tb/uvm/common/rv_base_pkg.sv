package rv_base_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class rv_base_seq_item extends uvm_sequence_item;
    `uvm_object_utils(rv_base_seq_item)

    function new(string name = "rv_base_seq_item");
      super.new(name);
    endfunction
  endclass

  class rv_base_driver #(type REQ = rv_base_seq_item)
      extends uvm_driver #(REQ);
    `uvm_component_param_utils(rv_base_driver #(REQ))

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class rv_base_monitor #(type ITEM = rv_base_seq_item)
      extends uvm_monitor;
    `uvm_component_param_utils(rv_base_monitor #(ITEM))

    uvm_analysis_port #(ITEM) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
  endclass

  class rv_base_agent #(type ITEM = rv_base_seq_item)
      extends uvm_agent;
    `uvm_component_param_utils(rv_base_agent #(ITEM))

    uvm_sequencer #(ITEM) sequencer;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (is_active == UVM_ACTIVE)
        sequencer = uvm_sequencer#(ITEM)::type_id::create("sequencer", this);
    endfunction
  endclass

  class rv_reset_util extends uvm_object;
    `uvm_object_utils(rv_reset_util)

    function new(string name = "rv_reset_util");
      super.new(name);
    endfunction

    static function bit reset_active(logic rst_n);
      return rst_n !== 1'b1;
    endfunction
  endclass
endpackage
