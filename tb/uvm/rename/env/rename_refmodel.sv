class rename_refmodel extends uvm_object;
  `uvm_object_utils(rename_refmodel)

  typedef struct {
    bit        valid;
    bit        complete;
    bit        reg_write;
    bit        is_branch;
    bit        is_store;
    bit        spec_en;
    bit        state_valid;
    br_state_t brch_state;
    gpr_addr_t rd;
    prf_addr_t prd;
    bit        branch_taken;
  } rob_entry_s;

  // RTL naming: map0 models map_br0_q (path1); map1 models map_br1_q (path0).
  prf_addr_t map0[NUM_GPR];
  prf_addr_t map1[NUM_GPR];
  prf_addr_t rrat[NUM_GPR];
  rob_entry_s rob[ROB_DEPTH];
  int unsigned write_ptr;
  int unsigned commit_ptr;
  int unsigned occupancy;
  bit        active_spec;

  function new(string name = "rename_refmodel");
    super.new(name);
    reset_all();
  endfunction

  function prf_addr_t to_prf(int unsigned idx);
    return prf_addr_t'({1'b1, 5'(idx % ROB_DEPTH)});
  endfunction

  function int unsigned to_flat(prf_addr_t tag);
    return int'(tag[ROB_AW-1:0]);
  endfunction

  function void reset_all();
    for (int i = 0; i < NUM_GPR; i++) begin
      map0[i] = prf_addr_t'(i);
      map1[i] = prf_addr_t'(i);
      rrat[i] = prf_addr_t'(i);
    end
    foreach (rob[i]) rob[i] = '{default:'0};
    write_ptr = 0;
    commit_ptr = 0;
    occupancy = 0;
    active_spec = 0;
  endfunction

  function void flush_speculation();
    for (int i = 0; i < NUM_GPR; i++) begin
      map0[i] = rrat[i];
      map1[i] = rrat[i];
    end
    foreach (rob[i]) rob[i] = '{default:'0};
    write_ptr = 0;
    commit_ptr = 0;
    occupancy = 0;
    active_spec = 0;
  endfunction

  function bit is_issue(rename_req_item req, int lane);
    return req.valid_rn[lane];
  endfunction

  function prf_addr_t map_read(gpr_addr_t arch, bit spec_en);
    if (arch == '0) return '0;
    return spec_en ? map0[arch] : map1[arch];
  endfunction

  function void step(
      rename_req_item req,
      rename_wb_item wb,
      output rename_req_item exp_req,
      output rename_wb_item exp_wb);
    bit issue[2], legal[2], go;
    bit on_path[2], ready[2], branch_commit[2];
    prf_addr_t new_tag[2];
    rob_entry_s head[2];
    bit path_after0, path_after1, winning_path;
    int idx, n_commit;
    int unsigned base;

    exp_req = rename_req_item::type_id::create("exp_req");
    exp_wb = rename_wb_item::type_id::create("exp_wb");

    if (!req.rst_n) begin
      reset_all();
      return;
    end
    if (req.flush) begin
      flush_speculation();
      return;
    end

    issue[0] = is_issue(req, 0);
    issue[1] = is_issue(req, 1);
    legal[0] = req.valid_rn[0] && req.reg_write[0] && (req.rd[0] != '0);
    legal[1] = req.valid_rn[1] && req.reg_write[1] && (req.rd[1] != '0);
    go = (occupancy <= ROB_DEPTH - 2) && (issue[0] || issue[1]);

    base = (write_ptr % ROB_DEPTH) & ~(1);
    new_tag[0] = (req.valid_rn[0] && req.reg_write[0]) ? to_prf(base) : '0;
    new_tag[1] = (req.valid_rn[1] && req.reg_write[1]) ? to_prf(base + 1) : '0;

    exp_req.stall = (occupancy > ROB_DEPTH - 2);
    for (int lane = 0; lane < 2; lane++) begin
      exp_req.valid[lane] = go && issue[lane];
      exp_req.prd[lane] = new_tag[lane];
      exp_req.rob_idx[lane] = to_prf(base | lane);
    end
    exp_req.ps1[0] = (!req.rs1_use[0] || req.rs1[0] == '0)
                   ? '0 : map_read(req.rs1[0], req.spec_en[0]);
    exp_req.ps2[0] = (!req.rs2_use[0] || req.rs2[0] == '0)
                   ? '0 : map_read(req.rs2[0], req.spec_en[0]);
    exp_req.ps1[1] = (!req.rs1_use[1] || req.rs1[1] == '0)
                   ? '0 : ((legal[0] && req.spec_en[0] == req.spec_en[1] &&
                            req.rs1[1] == req.rd[0])
                            ? new_tag[0] : map_read(req.rs1[1], req.spec_en[1]));
    exp_req.ps2[1] = (!req.rs2_use[1] || req.rs2[1] == '0)
                   ? '0 : ((legal[0] && req.spec_en[0] == req.spec_en[1] &&
                            req.rs2[1] == req.rd[0])
                            ? new_tag[0] : map_read(req.rs2[1], req.spec_en[1]));

    // Retire from registered ROB state first (no same-cycle WB bypass).
    // WB / alloc / reclaim below update state for the next cycle.
    head[0] = rob[commit_ptr % ROB_DEPTH];
    head[1] = rob[(commit_ptr + 1) % ROB_DEPTH];
    on_path[0] = !head[0].valid || head[0].spec_en == active_spec;
    ready[0] = head[0].valid && head[0].complete;
    branch_commit[0] = ready[0] && on_path[0] && head[0].is_branch;
    path_after0 = branch_commit[0] ? head[0].branch_taken : active_spec;

    on_path[1] = !head[1].valid || head[1].spec_en == path_after0;
    ready[1] = ready[0] && head[1].valid && head[1].complete;
    branch_commit[1] = ready[1] && on_path[1] && head[1].is_branch;
    path_after1 = branch_commit[1] ? head[1].branch_taken : path_after0;
    n_commit = ready[1] ? 2 : (ready[0] ? 1 : 0);

    for (int lane = 0; lane < 2; lane++) begin
      exp_wb.retire_en[lane] = ready[lane];
      exp_wb.commit_en[lane] = ready[lane] && on_path[lane] &&
                               head[lane].reg_write;
      exp_wb.commit_rd[lane] = head[lane].rd;
      exp_wb.commit_prd[lane] = to_prf((commit_ptr + lane) % ROB_DEPTH);
    end

    if (branch_commit[0] || branch_commit[1]) begin
      winning_path = branch_commit[1]
                   ? head[1].branch_taken : head[0].branch_taken;
      if (winning_path)
        for (int i = 0; i < NUM_GPR; i++) map1[i] = map0[i];
      else
        for (int i = 0; i < NUM_GPR; i++) map0[i] = map1[i];
    end

    if (n_commit != 0) begin
      for (int lane = 0; lane < n_commit; lane++) begin
        if (exp_wb.commit_en[lane])
          rrat[head[lane].rd] = exp_wb.commit_prd[lane];
        rob[(commit_ptr + lane) % ROB_DEPTH].valid = 0;
      end
      commit_ptr = (commit_ptr + n_commit) % (2 * ROB_DEPTH);
      occupancy -= n_commit;
      active_spec = ready[1] ? path_after1 : path_after0;
    end

    // Negedge-order storage updates for next cycle: WB → alloc → map
    for (int lane = 0; lane < 2; lane++) begin
      if (wb.wback_en[lane] && rob[to_flat(wb.rob_idx[lane])].valid) begin
        rob[to_flat(wb.rob_idx[lane])].complete = 1;
        rob[to_flat(wb.rob_idx[lane])].branch_taken = wb.branch_taken[lane];
      end
    end

    if (go) begin
      for (int lane = 0; lane < 2; lane++) begin
        idx = (base + lane) % ROB_DEPTH;
        rob[idx].valid = issue[lane];
        rob[idx].complete = 0;
        rob[idx].reg_write = issue[lane] && req.reg_write[lane];
        rob[idx].is_branch = issue[lane] && req.brch_en[lane];
        rob[idx].is_store = issue[lane] && req.store_en[lane];
        rob[idx].spec_en = req.spec_en[lane];
        rob[idx].state_valid = req.state_valid[lane];
        rob[idx].brch_state = req.brch_state[lane];
        rob[idx].rd = req.rd[lane];
        rob[idx].prd = to_prf(idx);
        rob[idx].branch_taken = 0;
      end
      write_ptr = (write_ptr + 2) % (2 * ROB_DEPTH);
      occupancy += 2;
    end

    if (go) begin
      for (int lane = 0; lane < 2; lane++) begin
        if (legal[lane]) begin
          if (req.spec_en[lane]) map0[req.rd[lane]] = new_tag[lane];
          else                    map1[req.rd[lane]] = new_tag[lane];
        end
      end
    end
  endfunction
endclass
