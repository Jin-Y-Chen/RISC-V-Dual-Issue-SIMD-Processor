`timescale 1ns / 1ps

// id_ex_dispatch_tb - Reorder Buffer dispatch (project_outline sec 1/2):
//   * enqueue decoded pairs at the write pointer
//   * route the oldest undispatched pair to even/odd lanes by lane_sel
//   * full ROB (occupancy = write - commit) back-pressures fetch via stall_id
//   * commit_en/commit_count free entries and release the stall
//   * flush squashes the buffer and resets the pointers
// Entries are compacted in program order, so the older VALID instruction is the
// slot-0 (ev0/od0) dispatch, the next is slot-1 (ev1/od1).
module id_ex_dispatch_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

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

  id_ex_dispatch dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    tb_advance(clk);
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
    input logic        exp_ev0,
    input logic        exp_ev1,
    input logic        exp_od0,
    input logic        exp_od1,
    input logic        exp_i0_rw,
    input logic        exp_i1_rw,
    input logic [31:0] exp_i0_pc,
    input logic [31:0] exp_i1_pc
  );
    bit pass;
    pass = (stall_id === exp_stall_id) &&
           (ev0_enable_ex === exp_ev0) && (ev1_enable_ex === exp_ev1) &&
           (od0_enable_ex === exp_od0) && (od1_enable_ex === exp_od1) &&
           (i0_reg_write_ex === exp_i0_rw) && (i1_reg_write_ex === exp_i1_rw) &&
           (i0_pc_ex === exp_i0_pc) && (i1_pc_ex === exp_i1_pc);

    tb_report_open(pass, name, detail);
    $display("  [outline] %s", outline_ref);
    log_id_inputs();
    $display("  --- EX outputs ---");
    tb_field_bit("stall_id", stall_id, exp_stall_id);
    tb_field_bit("ev0_enable_ex", ev0_enable_ex, exp_ev0);
    tb_field_bit("ev1_enable_ex", ev1_enable_ex, exp_ev1);
    tb_field_bit("od0_enable_ex", od0_enable_ex, exp_od0);
    tb_field_bit("od1_enable_ex", od1_enable_ex, exp_od1);
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

  // both slots idle (bubble), no commit
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

  // flush the ROB back to empty
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

    tb_banner("id_ex_dispatch_tb - Reorder Buffer dispatch (enqueue/route/stall/commit/flush)");

    // ------------------------------------------------------------------
    section_banner("Reset / flush");
    // ------------------------------------------------------------------

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
               "reset", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);

    rst_n = 1'b1;
    clear_rob();

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1020);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1024);
    flush = 1'b1;
    tick();
    check_case("flush_bubble", "flush squashes the buffer: no dispatch this cycle",
               "flush", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);
    flush = 1'b0;
    clear_rob();

    // ------------------------------------------------------------------
    section_banner("sec 2 routing - oldest pair to even/odd lanes by lane_sel");
    // ------------------------------------------------------------------

    set_slot0(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd5, 5'd0, 1'b1, 32'h2C, 32'h40, 32'h0, 32'h1100);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd2, 5'd5, 5'd0, 1'b1, 32'd0, 32'h50, 32'h0, 32'h1104,
              1'b1, 1'b0);
    tick();
    check_case("route_even_odd",
               "addi x1,x5,0x2c | lw x2,0(x5): slot0->ev0, slot1->od1",
               "sec 2 even|odd", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1,
               1'b1, 1'b1, 32'h1100, 32'h1104);
    clear_rob();

    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1200);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd4, 5'd10, 5'd11, 1'b1, 32'd0, 32'hB0, 32'hB1, 32'h1204);
    tick();
    check_case("route_even_even",
               "add x1,x2,x3 | sub x4,x5,x6: slot0->ev0, slot1->ev1",
               "sec 2 even|even", 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
               1'b1, 1'b1, 32'h1200, 32'h1204);
    clear_rob();

    set_slot0(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'd0, 32'hC0, 32'h0, 32'h1208);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd3, 5'd4, 5'd0, 1'b1, 32'd0, 32'hD0, 32'h0, 32'h120C);
    tick();
    check_case("route_odd_odd",
               "lw x1,0(x2) | lw x3,0(x4): slot0->od0, slot1->od1",
               "sec 2 odd|odd", 1'b0, 1'b0, 1'b0, 1'b1, 1'b1,
               1'b1, 1'b1, 32'h1208, 32'h120C);
    clear_rob();

    // ------------------------------------------------------------------
    section_banner("Validity gating - bubbles are not enqueued (program-order compaction)");
    // ------------------------------------------------------------------

    // I0 bubble: the younger valid insn becomes the slot-0 dispatch
    set_slot0(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1300);
    set_slot1(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd9, 5'd4, 5'd0, 1'b1, 32'd7, 32'h90, 32'h0, 32'h1304,
              1'b1, 1'b0);
    tick();
    check_case("i0_bubble", "I0 invalid: only the valid insn dispatches on slot0 (ev0)",
               "valid gating", 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
               1'b1, 1'b0, 32'h1304, 32'd0);
    clear_rob();

    set_slot0(1'b1, 1'b1, OPC_JAL, 3'd0, 7'd0,
              5'd1, 5'd0, 5'd0, 1'b1, 32'h100, 32'h0, 32'h0, 32'h1308);
    set_slot1(1'b0, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'h0, 32'h0, 32'h130C,
              1'b0, 1'b0);
    tick();
    check_case("i1_bubble", "I1 invalid: only I0 dispatches on slot0 (od0)",
               "valid gating", 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
               1'b1, 1'b0, 32'h1308, 32'd0);
    clear_rob();

    set_bubble();
    tick();
    check_case("both_bubble", "both invalid: nothing enqueued, full bubble",
               "valid gating", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);
    clear_rob();

    // ------------------------------------------------------------------
    section_banner("sec 1 Flow control - fill the ROB (no commit) -> stall_id");
    // ------------------------------------------------------------------

    // Push 8 even|even pairs without committing: 16 entries fills the buffer.
    for (int k = 0; k < 8; k++) begin
      set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
                5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3000 + k*8);
      set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
                5'd4, 5'd5, 5'd6, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3004 + k*8);
      tick();
    end

    // 9th pair cannot fit (occupancy = 16) -> stall fetch
    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd7, 5'd8, 5'd9, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3100);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd10, 5'd11, 5'd12, 1'b1, 32'd0, 32'd0, 32'd0, 32'h3104);
    check_stall("rob_full_stall", "ROB full (16 entries): incoming pair stalls fetch",
                "sec 1 flow control / full", 1'b1);

    // ------------------------------------------------------------------
    section_banner("sec 1 Commit (head pointer) frees entries -> stall releases");
    // ------------------------------------------------------------------

    commit_en    = 1'b1;
    commit_count = 2'd2;
    tick();
    commit_en    = 1'b0;
    commit_count = 2'd0;
    set_complete_en    = 1'b0;
    set_complete_idx   = 4'd0;
    set_complete_result = 32'd0;
    check_stall("commit_frees", "commit 2 entries: free slot opens, stall_id clears",
                "sec 1 commit", 1'b0);
    clear_rob();

    // ------------------------------------------------------------------
    section_banner("Stream - back-to-back pairs dispatch on consecutive cycles");
    // ------------------------------------------------------------------

    // pair A enqueues then dispatches next cycle
    set_slot0(1'b1, 1'b0, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'd5, 32'd0, 32'd0, 32'h4000);
    set_slot1(1'b1, 1'b1, OPC_LOAD, F3_LW, 7'd0,
              5'd3, 5'd4, 5'd0, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4004,
              1'b1, 1'b0);
    tick();
    check_case("stream_pair_a",
               "addi(even) | lw(odd): slot0->ev0, slot1->od1",
               "sec 1 stream", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1,
               1'b1, 1'b1, 32'h4000, 32'h4004);

    // pair B enqueues while A's read pointer advances; B dispatches this cycle
    set_slot0(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd5, 5'd6, 5'd7, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4010);
    set_slot1(1'b1, 1'b0, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd8, 5'd9, 5'd10, 1'b1, 32'd0, 32'd0, 32'd0, 32'h4014);
    tick();
    check_case("stream_pair_b",
               "add | sub: slot0->ev0, slot1->ev1 (A already advanced)",
               "sec 1 stream", 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
               1'b1, 1'b1, 32'h4010, 32'h4014);
    set_bubble();
    clear_rob();

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "id_ex_dispatch_tb failed");
    $finish;
  end

endmodule
