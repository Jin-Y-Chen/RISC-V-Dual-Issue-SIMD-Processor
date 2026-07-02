`timescale 1ns / 1ps

// id_ex_dispatch_tb - Reorder Buffer dispatch (project_outline sec 1/2):
//   * enqueue decoded pairs at the write pointer
//   * route the oldest undispatched pair to ev0/ev1/od0/od1 (lane_sel at dispatch)
//   * full ROB back-pressures fetch via stall_id
//   * commit_en/commit_count free entries and release the stall
//   * flush squashes the buffer and resets the pointers
module id_ex_dispatch_tb;

  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_queue_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;
  localparam string ROB_LOG_FILE = "rob_entries.txt";

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        flush;

  logic        commit_en;
  logic [1:0]  commit_count;

  logic        set_complete_en;
  logic [3:0]  set_complete_idx;
  logic [31:0] set_complete_result;

  logic        i0_valid_id;
  logic        i0_lane_sel_id;
  logic [6:0]  i0_opcode_id;
  logic [2:0]  i0_funct3_id;
  logic [6:0]  i0_funct7_id;
  logic [4:0]  i0_rd_addr_id;
  logic [4:0]  i0_rs1_addr_id;
  logic [4:0]  i0_rs2_addr_id;
  logic        i0_reg_write_id;
  logic [31:0] i0_imm_id;
  logic [31:0] i0_rs1_data_id;
  logic [31:0] i0_rs2_data_id;
  logic [31:0] i0_pc_id;

  logic        i1_valid_id;
  logic        i1_lane_sel_id;
  logic [6:0]  i1_opcode_id;
  logic [2:0]  i1_funct3_id;
  logic [6:0]  i1_funct7_id;
  logic [4:0]  i1_rd_addr_id;
  logic [4:0]  i1_rs1_addr_id;
  logic [4:0]  i1_rs2_addr_id;
  logic        i1_rs1_use_id;
  logic        i1_rs2_use_id;
  logic        i1_reg_write_id;
  logic [31:0] i1_imm_id;
  logic [31:0] i1_rs1_data_id;
  logic [31:0] i1_rs2_data_id;
  logic [31:0] i1_pc_id;

  logic        stall_id;

  logic        i0_reg_write_ex;
  logic        i1_reg_write_ex;
  logic [31:0] i0_pc_ex;
  logic [31:0] i1_pc_ex;

  logic        ev0_enable_ex;
  logic [6:0]  ev0_opcode_ex;
  logic [2:0]  ev0_funct3_ex;
  logic [6:0]  ev0_funct7_ex;
  logic [4:0]  ev0_rd_ex;
  logic [4:0]  ev0_rs1_addr_ex;
  logic [4:0]  ev0_rs2_addr_ex;
  logic [31:0] ev0_imm_ex;
  logic [31:0] ev0_rs1_data_ex;
  logic [31:0] ev0_rs2_data_ex;
  logic [31:0] ev0_pc_ex;

  logic        ev1_enable_ex;
  logic [6:0]  ev1_opcode_ex;
  logic [2:0]  ev1_funct3_ex;
  logic [6:0]  ev1_funct7_ex;
  logic [4:0]  ev1_rd_ex;
  logic [4:0]  ev1_rs1_addr_ex;
  logic [4:0]  ev1_rs2_addr_ex;
  logic [31:0] ev1_imm_ex;
  logic [31:0] ev1_rs1_data_ex;
  logic [31:0] ev1_rs2_data_ex;
  logic [31:0] ev1_pc_ex;

  logic        od0_enable_ex;
  logic [6:0]  od0_opcode_ex;
  logic [2:0]  od0_funct3_ex;
  logic [4:0]  od0_rd_ex;
  logic [4:0]  od0_rs1_addr_ex;
  logic [4:0]  od0_rs2_addr_ex;
  logic [31:0] od0_imm_ex;
  logic [31:0] od0_rs1_data_ex;
  logic [31:0] od0_rs2_data_ex;
  logic [31:0] od0_pc_ex;

  logic        od1_enable_ex;
  logic [6:0]  od1_opcode_ex;
  logic [2:0]  od1_funct3_ex;
  logic [4:0]  od1_rd_ex;
  logic [4:0]  od1_rs1_addr_ex;
  logic [4:0]  od1_rs2_addr_ex;
  logic [31:0] od1_imm_ex;
  logic [31:0] od1_rs1_data_ex;
  logic [31:0] od1_rs2_data_ex;
  logic [31:0] od1_pc_ex;

  int pass_cnt;
  int fail_cnt;
  int rob_fd;

  dispatch_core_struct dut (
    .clk                 (clk),
    .rst_n               (rst_n),
    .enable              (enable),
    .flush               (flush),
    .commit_en           (commit_en),
    .commit_count        (commit_count),
    .set_complete_en     (set_complete_en),
    .set_complete_idx    (set_complete_idx),
    .set_complete_result (set_complete_result),
    .i0_valid_dp         (i0_valid_id),
    .i0_lane_sel_dp      (i0_lane_sel_id),
    .i0_reg_write_dp     (i0_reg_write_id),
    .i1_valid_dp         (i1_valid_id),
    .i1_lane_sel_dp      (i1_lane_sel_id),
    .i1_rs1_use_dp       (i1_rs1_use_id),
    .i1_rs2_use_dp       (i1_rs2_use_id),
    .i1_reg_write_dp     (i1_reg_write_id),
    .i0_opcode_dp        (i0_opcode_id),
    .i0_funct3_dp        (i0_funct3_id),
    .i0_funct7_dp        (i0_funct7_id),
    .i0_rd_addr_dp       (i0_rd_addr_id),
    .i0_rs1_addr_dp      (i0_rs1_addr_id),
    .i0_rs2_addr_dp      (i0_rs2_addr_id),
    .i0_imm_dp           (i0_imm_id),
    .i0_rs1_data_dp      (i0_rs1_data_id),
    .i0_rs2_data_dp      (i0_rs2_data_id),
    .i0_pc_dp            (i0_pc_id),
    .i1_opcode_dp        (i1_opcode_id),
    .i1_funct3_dp        (i1_funct3_id),
    .i1_funct7_dp        (i1_funct7_id),
    .i1_rd_addr_dp       (i1_rd_addr_id),
    .i1_rs1_addr_dp      (i1_rs1_addr_id),
    .i1_rs2_addr_dp      (i1_rs2_addr_id),
    .i1_imm_dp           (i1_imm_id),
    .i1_rs1_data_dp      (i1_rs1_data_id),
    .i1_rs2_data_dp      (i1_rs2_data_id),
    .i1_pc_dp            (i1_pc_id),
    .stall_id            (stall_id),
    .i0_reg_write_disp   (i0_reg_write_ex),
    .i1_reg_write_disp   (i1_reg_write_ex),
    .i0_pc_disp          (i0_pc_ex),
    .i1_pc_disp          (i1_pc_ex),
    .ev0_enable_disp     (ev0_enable_ex),
    .ev0_opcode_disp     (ev0_opcode_ex),
    .ev0_funct3_disp     (ev0_funct3_ex),
    .ev0_funct7_disp     (ev0_funct7_ex),
    .ev0_rd_disp         (ev0_rd_ex),
    .ev0_rs1_addr_disp   (ev0_rs1_addr_ex),
    .ev0_rs2_addr_disp   (ev0_rs2_addr_ex),
    .ev0_imm_disp        (ev0_imm_ex),
    .ev0_rs1_data_disp   (ev0_rs1_data_ex),
    .ev0_rs2_data_disp   (ev0_rs2_data_ex),
    .ev0_pc_disp         (ev0_pc_ex),
    .ev1_enable_disp     (ev1_enable_ex),
    .ev1_opcode_disp     (ev1_opcode_ex),
    .ev1_funct3_disp     (ev1_funct3_ex),
    .ev1_funct7_disp     (ev1_funct7_ex),
    .ev1_rd_disp         (ev1_rd_ex),
    .ev1_rs1_addr_disp   (ev1_rs1_addr_ex),
    .ev1_rs2_addr_disp   (ev1_rs2_addr_ex),
    .ev1_imm_disp        (ev1_imm_ex),
    .ev1_rs1_data_disp   (ev1_rs1_data_ex),
    .ev1_rs2_data_disp   (ev1_rs2_data_ex),
    .ev1_pc_disp         (ev1_pc_ex),
    .od0_enable_disp     (od0_enable_ex),
    .od0_opcode_disp     (od0_opcode_ex),
    .od0_funct3_disp     (od0_funct3_ex),
    .od0_rd_disp         (od0_rd_ex),
    .od0_rs1_addr_disp   (od0_rs1_addr_ex),
    .od0_rs2_addr_disp   (od0_rs2_addr_ex),
    .od0_imm_disp        (od0_imm_ex),
    .od0_rs1_data_disp   (od0_rs1_data_ex),
    .od0_rs2_data_disp   (od0_rs2_data_ex),
    .od0_pc_disp         (od0_pc_ex),
    .od1_enable_disp     (od1_enable_ex),
    .od1_opcode_disp     (od1_opcode_ex),
    .od1_funct3_disp     (od1_funct3_ex),
    .od1_rd_disp         (od1_rd_ex),
    .od1_rs1_addr_disp   (od1_rs1_addr_ex),
    .od1_rs2_addr_disp   (od1_rs2_addr_ex),
    .od1_imm_disp        (od1_imm_ex),
    .od1_rs1_data_disp   (od1_rs1_data_ex),
    .od1_rs2_data_disp   (od1_rs2_data_ex),
    .od1_pc_disp         (od1_pc_ex)
  );

  initial clk = 1'b0;

  function automatic string rob_state_str(input rob_state_t state);
    case (state)
      ROB_NEW:       return "NEW(000)";
      ROB_READ:      return "READ(001)";
      ROB_EXECUTED:  return "EXEC(010)";
      ROB_SPEC_NEW:  return "SNEW(100)";
      ROB_SPEC_READ: return "SRD(101)";
      ROB_SPEC_EXEC: return "SEX(110)";
      default:       return $sformatf("???(%03b)", state);
    endcase
  endfunction

  function automatic string rob_slot_flags(input int idx);
    logic [ROB_AW-1:0] slot;
    logic [ROB_AW-1:0] commit_idx;
    logic [ROB_AW-1:0] read_idx;
    logic [ROB_AW-1:0] write_idx;
    string flags;
    slot       = idx[ROB_AW-1:0];
    commit_idx = dut.rob_commit_ptr[ROB_AW-1:0];
    read_idx   = dut.rob_read_ptr[ROB_AW-1:0];
    write_idx  = dut.rob_write_ptr[ROB_AW-1:0];
    flags = "";
    if (slot == commit_idx)
      flags = {flags, "C"};
    if (slot == read_idx)
      flags = {flags, "R"};
    if (slot == write_idx)
      flags = {flags, "W"};
    if (flags == "")
      rob_slot_flags = "-";
    else
      rob_slot_flags = flags;
  endfunction

  task automatic dump_rob(input string label = "");
    rob_entry_t entry;
    rob_ptr_t   occupancy;
    occupancy = dut.rob_write_ptr - dut.rob_commit_ptr;
    $fwrite(rob_fd, "\n================================================================================\n");
    if (label != "")
      $fdisplay(rob_fd, "ROB snapshot | %s | t=%0t ns", label, $time);
    else
      $fdisplay(rob_fd, "ROB snapshot | t=%0t ns", $time);
    $fdisplay(rob_fd,
      "pointers: commit=%0d read=%0d write=%0d occupancy=%0d stall=%0d br_inflight=%0d",
      dut.rob_commit_ptr, dut.rob_read_ptr, dut.rob_write_ptr, occupancy,
      stall_id, dut.br_inflight);
    $fdisplay(rob_fd,
      "flags: C=commit(head) R=read(body) W=write(tail) | state: NEW/READ/EXEC + spec variants");
    $fdisplay(rob_fd,
      " idx flg v tag  state       lane    pc       opcode  rd  result");
    $fdisplay(rob_fd,
      " --- --- - ---- ----------- ----- -------- ------- --- --------");
    for (int i = 0; i < ROB_DEPTH; i++) begin
      entry = rob_cache_read_entry(dut.rob_bank[i], dut.rob_tag[i]);
      if (!entry.valid) begin
        $fdisplay(rob_fd, " %2d %3s 0  --   (empty)     -     -        -     -   -",
                  i, rob_slot_flags(i));
      end else begin
        $fdisplay(rob_fd,
          " %2d %3s 1 x%0d %-11s %5s 0x%08h %07b x%0d 0x%08h",
          i, rob_slot_flags(i), entry.tag, rob_state_str(entry.data.state),
          entry.data.packet.lane_sel ? "ODD" : "EVEN",
          entry.data.packet.pc, entry.data.packet.opcode, entry.tag,
          entry.data.result);
      end
    end
    $fflush(rob_fd);
  endtask

  task automatic tick(input string rob_label = "");
    #(CLK_PERIOD / 2);
    clk = 1'b1;
    #(CLK_PERIOD / 2);
    clk = 1'b0;
    #0;
    dump_rob(rob_label);
  endtask

  function automatic string lane_name(input logic lane);
    lane_name = lane ? "ODD" : "EVEN";
  endfunction

  task automatic log_val_bit(input string label, input logic val);
    $display("  %-16s = %0d", label, val);
  endtask

  task automatic log_val_lane(input string label, input logic val);
    $display("  %-16s = %s", label, lane_name(val));
  endtask

  task automatic log_val_u5(input string label, input logic [4:0] val);
    $display("  %-16s = x%0d", label, val);
  endtask

  task automatic log_val_u32(input string label, input logic [31:0] val);
    $display("  %-16s = 0x%08h", label, val);
  endtask

  task automatic log_val_op7(input string label, input logic [6:0] val);
    $display("  %-16s = %07b", label, val);
  endtask

  task automatic log_id_inputs;
    $display("  --- ID inputs (driven) ---");
    log_val_bit("flush", flush);
    log_val_bit("commit_en", commit_en);
    $display("  %-16s = %0d", "commit_count", commit_count);
    log_val_bit("i0_valid_id", i0_valid_id);
    log_val_lane("i0_lane_sel_id", i0_lane_sel_id);
    log_val_op7("i0_opcode_id", i0_opcode_id);
    log_val_u5("i0_rd_addr_id", i0_rd_addr_id);
    log_val_bit("i0_reg_write_id", i0_reg_write_id);
    log_val_u32("i0_pc_id", i0_pc_id);
    log_val_bit("i1_valid_id", i1_valid_id);
    log_val_lane("i1_lane_sel_id", i1_lane_sel_id);
    log_val_op7("i1_opcode_id", i1_opcode_id);
    log_val_u5("i1_rd_addr_id", i1_rd_addr_id);
    log_val_bit("i1_reg_write_id", i1_reg_write_id);
    log_val_u32("i1_pc_id", i1_pc_id);
  endtask

  task automatic check_case(
    input string name,
    input string detail,
    input string outline_ref,
    input logic        exp_stall_id,
    input logic        exp_i0_valid,
    input logic        exp_i1_valid,
    input logic        exp_i0_rw,
    input logic        exp_i1_rw,
    input logic [31:0] exp_i0_pc,
    input logic [31:0] exp_i1_pc,
    input logic        exp_i0_lane = 1'b0,
    input logic        exp_i1_lane = 1'b0
  );
    logic exp_i0_ev;
    logic exp_i0_od;
    logic exp_i1_ev;
    logic exp_i1_od;
    bit pass;

    exp_i0_ev = exp_i0_valid && !exp_i0_lane;
    exp_i0_od = exp_i0_valid &&  exp_i0_lane;
    exp_i1_ev = exp_i1_valid && !exp_i1_lane;
    exp_i1_od = exp_i1_valid &&  exp_i1_lane;

    pass = (stall_id === exp_stall_id) &&
           (ev0_enable_ex === exp_i0_ev) && (od0_enable_ex === exp_i0_od) &&
           (ev1_enable_ex === exp_i1_ev) && (od1_enable_ex === exp_i1_od) &&
           (i0_reg_write_ex === exp_i0_rw) && (i1_reg_write_ex === exp_i1_rw) &&
           (i0_pc_ex === exp_i0_pc) && (i1_pc_ex === exp_i1_pc);

    tb_report_open(pass, name, detail);
    $fwrite(rob_fd, "\n>>> TEST: %s | %s\n", name, detail);
    $display("  [outline] %s", outline_ref);
    log_id_inputs();
    $display("  --- EX outputs ---");
    tb_field_bit("stall_id", stall_id, exp_stall_id);
    tb_field_bit("ev0_enable_ex", ev0_enable_ex, exp_i0_ev);
    tb_field_bit("od0_enable_ex", od0_enable_ex, exp_i0_od);
    tb_field_bit("ev1_enable_ex", ev1_enable_ex, exp_i1_ev);
    tb_field_bit("od1_enable_ex", od1_enable_ex, exp_i1_od);
    tb_field_bit("i0_reg_write_ex", i0_reg_write_ex, exp_i0_rw);
    tb_field_bit("i1_reg_write_ex", i1_reg_write_ex, exp_i1_rw);
    tb_field_u32("i0_pc_ex", i0_pc_ex, exp_i0_pc);
    tb_field_u32("i1_pc_ex", i1_pc_ex, exp_i1_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_stall(
    input string name,
    input string detail,
    input string outline_ref,
    input logic   exp_stall_id
  );
    bit pass;
    pass = (stall_id === exp_stall_id);
    tb_report_open(pass, name, detail);
    $fwrite(rob_fd, "\n>>> TEST: %s | %s\n", name, detail);
    dump_rob(name);
    $display("  [outline] %s", outline_ref);
    log_id_inputs();
    $display("  --- EX outputs ---");
    tb_field_bit("stall_id", stall_id, exp_stall_id);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic set_slot0(
    input logic        valid,
    input logic        lane,
    input logic [6:0]  opcode,
    input logic [2:0]  funct3,
    input logic [6:0]  funct7,
    input logic [4:0]  rd,
    input logic [4:0]  rs1,
    input logic [4:0]  rs2,
    input logic        reg_write,
    input logic [31:0] imm,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [31:0] pc
  );
    i0_valid_id     = valid;
    i0_lane_sel_id  = lane;
    i0_opcode_id    = opcode;
    i0_funct3_id    = funct3;
    i0_funct7_id    = funct7;
    i0_rd_addr_id   = rd;
    i0_rs1_addr_id  = rs1;
    i0_rs2_addr_id  = rs2;
    i0_reg_write_id = reg_write;
    i0_imm_id       = imm;
    i0_rs1_data_id  = rs1_data;
    i0_rs2_data_id  = rs2_data;
    i0_pc_id        = pc;
  endtask

  task automatic set_slot1(
    input logic        valid,
    input logic        lane,
    input logic [6:0]  opcode,
    input logic [2:0]  funct3,
    input logic [6:0]  funct7,
    input logic [4:0]  rd,
    input logic [4:0]  rs1,
    input logic [4:0]  rs2,
    input logic        reg_write,
    input logic [31:0] imm,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [31:0] pc,
    input logic        rs1_use = 1'b1,
    input logic        rs2_use = 1'b1
  );
    i1_valid_id     = valid;
    i1_lane_sel_id  = lane;
    i1_opcode_id    = opcode;
    i1_funct3_id    = funct3;
    i1_funct7_id    = funct7;
    i1_rd_addr_id   = rd;
    i1_rs1_addr_id  = rs1;
    i1_rs2_addr_id  = rs2;
    i1_rs1_use_id   = rs1_use;
    i1_rs2_use_id   = rs2_use;
    i1_reg_write_id = reg_write;
    i1_imm_id       = imm;
    i1_rs1_data_id  = rs1_data;
    i1_rs2_data_id  = rs2_data;
    i1_pc_id        = pc;
  endtask

  task automatic set_bubble;
    set_slot0(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0);
    set_slot1(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0,
              1'b0, 1'b0);
    commit_en    = 1'b0;
    commit_count = 2'd0;
    set_complete_en    = 1'b0;
    set_complete_idx   = 4'd0;
    set_complete_result = 32'd0;
  endtask

  task automatic clear_rob;
    set_bubble();
    flush = 1'b1;
    tick();
    flush = 1'b0;
  endtask

  task automatic section_banner(input string msg);
    $display("");
    tb_banner(msg);
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    rob_fd = $fopen(ROB_LOG_FILE, "w");
    if (rob_fd == 0)
      $fatal(1, "id_ex_dispatch_tb: cannot open %s for ROB trace", ROB_LOG_FILE);
    $fdisplay(rob_fd, "id_ex_dispatch_tb — Reorder Buffer entry trace");
    $fdisplay(rob_fd, "Generated by tb/s3_execute/id_ex_dispatch_tb.sv");
    $fdisplay(rob_fd, "File: %s (simulator working directory)", ROB_LOG_FILE);
    $fflush(rob_fd);

    tb_banner("id_ex_dispatch_tb - Reorder Buffer dispatch (ev/od lane routing)");

    section_banner("Reset / flush");

    rst_n  = 1'b0;
    enable = 1'b1;
    flush  = 1'b0;
    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1000);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1004,
              1'b1, 1'b0);
    commit_en    = 1'b0;
    commit_count = 2'd0;
    set_complete_en    = 1'b0;
    set_complete_idx   = 4'd0;
    set_complete_result = 32'd0;
    tick();
    check_case("reset_clear", "active-low reset holds pointers empty, no dispatch",
               "reset", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'd0, 32'd0);

    rst_n = 1'b1;
    clear_rob();

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1020);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1024);
    flush = 1'b1;
    tick();
    check_case("flush_bubble", "flush squashes the buffer: no dispatch this cycle",
               "flush", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'd0, 32'd0);
    flush = 1'b0;
    clear_rob();

    section_banner("sec 2 dispatch - oldest pair routed to ev/od lanes");

    set_slot0(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd5, 5'd0, 1'b1, 32'h2C, 32'h40, 32'h0, 32'h1100);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd2, 5'd5, 5'd0, 1'b1, 32'd0, 32'h50, 32'h0, 32'h1104,
              1'b1, 1'b0);
    tick();
    check_case("dispatch_even_odd",
               "addi x1,x5,0x2c | lw x2,0(x5): ev0 + od1",
               "sec 2 even|odd", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1,
               32'h1100, 32'h1104, 1'b0, 1'b1);
    clear_rob();

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1200);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd4, 5'd10, 5'd11, 1'b1, 32'd0, 32'hB0, 32'hB1, 32'h1204);
    tick();
    check_case("dispatch_even_even",
               "add x1,x2,x3 | sub x4,x5,x6: ev0 + ev1",
               "sec 2 even|even", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1,
               32'h1200, 32'h1204, 1'b0, 1'b0);
    clear_rob();

    set_slot0(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'd0, 32'hC0, 32'h0, 32'h1208);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd3, 5'd4, 5'd0, 1'b1, 32'd0, 32'hD0, 32'h0, 32'h120C);
    tick();
    check_case("dispatch_odd_odd",
               "lw x1,0(x2) | lw x3,0(x4): od0 + od1",
               "sec 2 odd|odd", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1,
               32'h1208, 32'h120C, 1'b1, 1'b1);
    clear_rob();

    section_banner("Validity gating");

    set_slot0(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1300);
    set_slot1(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd9, 5'd4, 5'd0, 1'b1, 32'd7, 32'h90, 32'h0, 32'h1304,
              1'b1, 1'b0);
    tick();
    check_case("i0_bubble", "I0 invalid: only first ROB entry on ev0",
               "valid gating", 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
               32'h1304, 32'd0, 1'b0, 1'b0);
    clear_rob();

    set_slot0(1'b1, 1'b1, OPC_JAL, 3'd0, 7'd0,
              5'd1, 5'd0, 5'd0, 1'b1, 32'h100, 32'h0, 32'h0, 32'h1308);
    set_slot1(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'h0, 32'h0, 32'h130C,
              1'b0, 1'b0);
    tick();
    check_case("i1_bubble", "I1 invalid: only first ROB entry on od0",
               "valid gating", 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
               32'h1308, 32'd0, 1'b1, 1'b0);
    clear_rob();

    set_bubble();
    tick();
    check_case("both_bubble", "both invalid: full bubble",
               "valid gating", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'd0, 32'd0);
    clear_rob();

    section_banner("sec 1 Flow control - ROB full -> stall_id");

    for (int k = 0; k < 8; k++) begin
      set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
                5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3000 + k*8);
      set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
                5'd4, 5'd5, 5'd6, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3004 + k*8);
      tick();
    end

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd7, 5'd8, 5'd9, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3100);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd10, 5'd11, 5'd12, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3104);
    check_stall("rob_full_stall", "ROB full: incoming pair stalls fetch",
                "sec 1 flow control / full", 1'b1);

    section_banner("sec 1 Commit frees entries");

    commit_en    = 1'b1;
    commit_count = 2'd2;
    tick();
    commit_en    = 1'b0;
    commit_count = 2'd0;
    set_complete_en    = 1'b0;
    set_complete_idx   = 4'd0;
    set_complete_result = 32'd0;
    check_stall("commit_frees", "commit 2 entries: stall_id clears",
                "sec 1 commit", 1'b0);
    clear_rob();

    section_banner("Stream - back-to-back pairs");

    set_slot0(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'd5, 32'd0, 32'd0, 32'h4000);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd3, 5'd4, 5'd0, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4004,
              1'b1, 1'b0);
    tick();
    check_case("stream_pair_a",
               "addi(even) | lw(odd): ev0 + od1",
               "sec 1 stream", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1,
               32'h4000, 32'h4004, 1'b0, 1'b1);

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd5, 5'd6, 5'd7, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4010);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd8, 5'd9, 5'd10, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4014);
    tick();
    check_case("stream_pair_b",
               "add | sub: ev0 + ev1",
               "sec 1 stream", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1,
               32'h4010, 32'h4014, 1'b0, 1'b0);
    set_bubble();
    clear_rob();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    $fdisplay(rob_fd, "\n=== SIM END: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
    $fclose(rob_fd);
    $display("[INFO] ROB trace written to %s", ROB_LOG_FILE);
    if (fail_cnt != 0)
      $fatal(1, "id_ex_dispatch_tb failed");
    $finish;
  end

endmodule
