`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_wb)

class rename_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(rename_scoreboard)

  uvm_analysis_imp_req #(rename_req_item, rename_scoreboard) req_imp;
  uvm_analysis_imp_wb  #(rename_wb_item,  rename_scoreboard) wb_imp;
  rename_req_item req_q[$];
  rename_wb_item  wb_q[$];
  rename_refmodel model;
  bit allocated[NUM_PRF];
  int unsigned checks;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_imp = new("req_imp", this);
    wb_imp = new("wb_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    model = rename_refmodel::type_id::create("model");
    reset_ownership();
  endfunction

  function void reset_ownership();
    foreach (allocated[i]) allocated[i] = (i < NUM_GPR);
  endfunction

  function void restore_committed_ownership();
    foreach (allocated[i]) allocated[i] = 0;
    for (int i = 0; i < NUM_GPR; i++)
      allocated[model.rrat[i]] = 1;
  endfunction

  function void write_req(rename_req_item item);
    req_q.push_back(item);
    try_process();
  endfunction

  function void write_wb(rename_wb_item item);
    wb_q.push_back(item);
    try_process();
  endfunction

  function void try_process();
    rename_req_item req, exp_req;
    rename_wb_item wb, exp_wb;

    while (req_q.size() && wb_q.size()) begin
      req = req_q.pop_front();
      wb = wb_q.pop_front();
      model.step(req, wb, exp_req, exp_wb);

      if (!req.rst_n || req.flush) begin
        if (!req.rst_n)
          reset_ownership();
        else
          restore_committed_ownership();
        continue;
      end

      check_bit("stall_id", req.stall, exp_req.stall);
      for (int lane = 0; lane < 2; lane++) begin
        check_bit($sformatf("i%0d_valid_disp", lane),
                  req.valid[lane], exp_req.valid[lane]);
        if (exp_req.valid[lane]) begin
          check_tag($sformatf("i%0d_ps1_disp", lane),
                    req.ps1[lane], exp_req.ps1[lane]);
          check_tag($sformatf("i%0d_ps2_disp", lane),
                    req.ps2[lane], exp_req.ps2[lane]);
          check_tag($sformatf("i%0d_prd_disp", lane),
                    req.prd[lane], exp_req.prd[lane]);
          check_idx($sformatf("i%0d_rob_idx_disp", lane),
                    req.rob_idx[lane], exp_req.rob_idx[lane]);
          // ROB slot tag is already PRF-wide (p32..p63)
          if (allocated[prf_addr_t'(req.rob_idx[lane])])
            `uvm_error("PRF_OWNERSHIP",
              $sformatf("p%0d ROB slot reused while still in flight",
                        req.rob_idx[lane]))
          allocated[prf_addr_t'(req.rob_idx[lane])] = 1;
        end

        check_bit($sformatf("i%0d_commit_en", lane),
                  wb.commit_en[lane], exp_wb.commit_en[lane]);
        if (exp_wb.commit_en[lane]) begin
          check_gpr($sformatf("i%0d_commit_rd", lane),
                    wb.commit_rd[lane], exp_wb.commit_rd[lane]);
          check_tag($sformatf("i%0d_commit_prd", lane),
                    wb.commit_prd[lane], exp_wb.commit_prd[lane]);
        end
        if (exp_wb.retire_en[lane])
          allocated[exp_wb.commit_prd[lane]] = 0;
      end
      checks++;
    end
  endfunction

  function void check_bit(string field, logic actual, logic expected);
    if (actual !== expected)
      `uvm_error("RENAME_MISMATCH",
        $sformatf("%s actual=%0b expected=%0b", field, actual, expected))
  endfunction

  function void check_tag(string field, prf_addr_t actual, prf_addr_t expected);
    if (actual !== expected)
      `uvm_error("RENAME_MISMATCH",
        $sformatf("%s actual=p%0d expected=p%0d", field, actual, expected))
  endfunction

  function void check_gpr(string field, gpr_addr_t actual, gpr_addr_t expected);
    if (actual !== expected)
      `uvm_error("RENAME_MISMATCH",
        $sformatf("%s actual=x%0d expected=x%0d", field, actual, expected))
  endfunction

  function void check_idx(string field, prf_addr_t actual, prf_addr_t expected);
    if (actual !== expected)
      `uvm_error("RENAME_MISMATCH",
        $sformatf("%s actual=%0d expected=%0d", field, actual, expected))
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (req_q.size() != 0 || wb_q.size() != 0)
      `uvm_error("UNPAIRED_SAMPLES",
        $sformatf("request samples=%0d writeback samples=%0d",
                  req_q.size(), wb_q.size()))
    if (checks == 0)
      `uvm_error("NO_CHECKS", "scoreboard did not process any active cycles")
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("RENAME_SCOREBOARD",
      $sformatf("completed %0d cycle checks", checks), UVM_LOW)
  endfunction
endclass
