class rename_env_cfg extends uvm_object;
  `uvm_object_utils(rename_env_cfg)

  virtual rename_if vif;
  uvm_active_passive_enum req_is_active = UVM_ACTIVE;
  uvm_active_passive_enum wb_is_active = UVM_ACTIVE;
  bit coverage_enable = 1;

  function new(string name = "rename_env_cfg");
    super.new(name);
  endfunction
endclass
