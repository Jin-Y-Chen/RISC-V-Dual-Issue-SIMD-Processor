`timescale 1ns / 1ps

// id_ex_dispatch_tb - lane routing (fixed slot map), per-slot WB controls,
// reset / flush behavior of the ID/EX dispatch register.
module id_ex_dispatch_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        flush;

  // I0 slot inputs
  logic        i0_valid_id;
  lane_sel_e   i0_lane_sel_id;
  logic [6:0]  i0_opcode_id;
  logic [2:0]  i0_funct3_id;
  logic [6:0]  i0_funct7_id;
  logic [4:0]  i0_rd_addr_id;
  logic [4:0]  i0_rs1_addr_id;
  logic [4:0]  i0_rs2_addr_id;
  logic        i0_rs1_use_id;
  logic        i0_rs2_use_id;
  logic        i0_reg_write_id;
  logic [31:0] i0_imm_id;
  logic [31:0] i0_rs1_data_id;
  logic [31:0] i0_rs2_data_id;
  logic [31:0] i0_pc_id;

  // I1 slot inputs
  logic        i1_valid_id;
  lane_sel_e   i1_lane_sel_id;
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

  logic        stall_mem;
  logic        mem0_reg_write;
  logic [4:0]  mem0_rd;
  logic        mem1_reg_write;
  logic [4:0]  mem1_rd;
  logic        wb0_reg_write;
  logic [4:0]  wb0_rd;
  logic        wb1_reg_write;
  logic [4:0]  wb1_rd;

  logic        stall_id;
  logic        i1_hold_active;
  logic        bundle_raw;

  // Per-slot WB controls
  logic        i0_reg_write_ex;
  logic        i1_reg_write_ex;
  logic [31:0] i0_pc_ex;
  logic [31:0] i1_pc_ex;

  // Even lane pair
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

  // Odd lane pair
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

  assign stall_mem = 1'b0;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic tick;
    @(posedge clk);
    #1step;
  endtask

  task automatic set_slot0(
    input logic        valid,
    input lane_sel_e   lane,
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
    i0_valid_id     = valid;
    i0_lane_sel_id  = lane;
    i0_opcode_id    = opcode;
    i0_funct3_id    = funct3;
    i0_funct7_id    = funct7;
    i0_rd_addr_id   = rd;
    i0_rs1_addr_id  = rs1;
    i0_rs2_addr_id  = rs2;
    i0_rs1_use_id   = rs1_use;
    i0_rs2_use_id   = rs2_use;
    i0_reg_write_id = reg_write;
    i0_imm_id       = imm;
    i0_rs1_data_id  = rs1_data;
    i0_rs2_data_id  = rs2_data;
    i0_pc_id        = pc;
  endtask

  task automatic set_slot1(
    input logic        valid,
    input lane_sel_e   lane,
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

  task automatic check_stall(
    input string name,
    input string detail,
    input logic  exp_stall_id,
    input logic  exp_i1_hold,
    input logic  exp_bundle_raw
  );
    bit pass;
    pass = (stall_id === exp_stall_id) && (i1_hold_active === exp_i1_hold) &&
           (bundle_raw === exp_bundle_raw);
    tb_report_open(pass, name, detail);
    tb_field_bit("stall_id", stall_id, exp_stall_id);
    tb_field_bit("i1_hold_active", i1_hold_active, exp_i1_hold);
    tb_field_bit("bundle_raw", bundle_raw, exp_bundle_raw);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic flush_busy;
    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0,
              1'b0, 1'b0);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0,
              1'b0, 1'b0);
    flush = 1'b1;
    tick();
    flush = 1'b0;
    mem0_reg_write = 1'b0;
    mem1_reg_write = 1'b0;
    wb0_reg_write  = 1'b0;
    wb1_reg_write  = 1'b0;
    mem0_rd        = 5'd0;
    mem1_rd        = 5'd0;
    wb0_rd         = 5'd0;
    wb1_rd         = 5'd0;
  endtask

  task automatic check_enables(
    input string name,
    input string detail,
    input logic  exp_ev0,
    input logic  exp_ev1,
    input logic  exp_od0,
    input logic  exp_od1
  );
    bit pass;
    pass = (ev0_enable_ex === exp_ev0) && (ev1_enable_ex === exp_ev1) &&
           (od0_enable_ex === exp_od0) && (od1_enable_ex === exp_od1);
    tb_report_open(pass, name, detail);
    tb_field_bit("ev0_enable_ex", ev0_enable_ex, exp_ev0);
    tb_field_bit("ev1_enable_ex", ev1_enable_ex, exp_ev1);
    tb_field_bit("od0_enable_ex", od0_enable_ex, exp_od0);
    tb_field_bit("od1_enable_ex", od1_enable_ex, exp_od1);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_wb_ctrl(
    input string       name,
    input string       detail,
    input logic        exp_i0_rw,
    input logic        exp_i1_rw,
    input logic [31:0] exp_i0_pc,
    input logic [31:0] exp_i1_pc
  );
    bit pass;
    pass = (i0_reg_write_ex === exp_i0_rw) && (i1_reg_write_ex === exp_i1_rw) &&
           (i0_pc_ex === exp_i0_pc) && (i1_pc_ex === exp_i1_pc);
    tb_report_open(pass, name, detail);
    tb_field_bit("i0_reg_write_ex", i0_reg_write_ex, exp_i0_rw);
    tb_field_bit("i1_reg_write_ex", i1_reg_write_ex, exp_i1_rw);
    tb_field_u32("i0_pc_ex", i0_pc_ex, exp_i0_pc);
    tb_field_u32("i1_pc_ex", i1_pc_ex, exp_i1_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_ev0(
    input string       name,
    input string       detail,
    input logic [6:0]  exp_opcode,
    input logic [2:0]  exp_funct3,
    input logic [6:0]  exp_funct7,
    input logic [4:0]  exp_rd,
    input logic [4:0]  exp_rs1,
    input logic [4:0]  exp_rs2,
    input logic [31:0] exp_imm,
    input logic [31:0] exp_rs1_data,
    input logic [31:0] exp_rs2_data,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (ev0_opcode_ex === exp_opcode) && (ev0_funct3_ex === exp_funct3) &&
           (ev0_funct7_ex === exp_funct7) && (ev0_rd_ex === exp_rd) &&
           (ev0_rs1_addr_ex === exp_rs1) && (ev0_rs2_addr_ex === exp_rs2) &&
           (ev0_imm_ex === exp_imm) &&
           (ev0_rs1_data_ex === exp_rs1_data) && (ev0_rs2_data_ex === exp_rs2_data) &&
           (ev0_pc_ex === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_op7("ev0_opcode_ex", ev0_opcode_ex, exp_opcode);
    tb_field_f3("ev0_funct3_ex", ev0_funct3_ex, exp_funct3);
    tb_field_f7("ev0_funct7_ex", ev0_funct7_ex, exp_funct7);
    tb_field_u5("ev0_rd_ex", ev0_rd_ex, exp_rd);
    tb_field_u5("ev0_rs1_addr_ex", ev0_rs1_addr_ex, exp_rs1);
    tb_field_u5("ev0_rs2_addr_ex", ev0_rs2_addr_ex, exp_rs2);
    tb_field_u32("ev0_imm_ex", ev0_imm_ex, exp_imm);
    tb_field_u32("ev0_rs1_data_ex", ev0_rs1_data_ex, exp_rs1_data);
    tb_field_u32("ev0_rs2_data_ex", ev0_rs2_data_ex, exp_rs2_data);
    tb_field_u32("ev0_pc_ex", ev0_pc_ex, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_ev1(
    input string       name,
    input string       detail,
    input logic [6:0]  exp_opcode,
    input logic [2:0]  exp_funct3,
    input logic [6:0]  exp_funct7,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_imm,
    input logic [31:0] exp_rs1_data,
    input logic [31:0] exp_rs2_data,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (ev1_opcode_ex === exp_opcode) && (ev1_funct3_ex === exp_funct3) &&
           (ev1_funct7_ex === exp_funct7) && (ev1_rd_ex === exp_rd) &&
           (ev1_imm_ex === exp_imm) &&
           (ev1_rs1_data_ex === exp_rs1_data) && (ev1_rs2_data_ex === exp_rs2_data) &&
           (ev1_pc_ex === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_op7("ev1_opcode_ex", ev1_opcode_ex, exp_opcode);
    tb_field_f3("ev1_funct3_ex", ev1_funct3_ex, exp_funct3);
    tb_field_f7("ev1_funct7_ex", ev1_funct7_ex, exp_funct7);
    tb_field_u5("ev1_rd_ex", ev1_rd_ex, exp_rd);
    tb_field_u32("ev1_imm_ex", ev1_imm_ex, exp_imm);
    tb_field_u32("ev1_rs1_data_ex", ev1_rs1_data_ex, exp_rs1_data);
    tb_field_u32("ev1_rs2_data_ex", ev1_rs2_data_ex, exp_rs2_data);
    tb_field_u32("ev1_pc_ex", ev1_pc_ex, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_od0(
    input string       name,
    input string       detail,
    input logic [6:0]  exp_opcode,
    input logic [2:0]  exp_funct3,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_imm,
    input logic [31:0] exp_rs1_data,
    input logic [31:0] exp_rs2_data,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (od0_opcode_ex === exp_opcode) && (od0_funct3_ex === exp_funct3) &&
           (od0_rd_ex === exp_rd) && (od0_imm_ex === exp_imm) &&
           (od0_rs1_data_ex === exp_rs1_data) && (od0_rs2_data_ex === exp_rs2_data) &&
           (od0_pc_ex === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_op7("od0_opcode_ex", od0_opcode_ex, exp_opcode);
    tb_field_f3("od0_funct3_ex", od0_funct3_ex, exp_funct3);
    tb_field_u5("od0_rd_ex", od0_rd_ex, exp_rd);
    tb_field_u32("od0_imm_ex", od0_imm_ex, exp_imm);
    tb_field_u32("od0_rs1_data_ex", od0_rs1_data_ex, exp_rs1_data);
    tb_field_u32("od0_rs2_data_ex", od0_rs2_data_ex, exp_rs2_data);
    tb_field_u32("od0_pc_ex", od0_pc_ex, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_od1(
    input string       name,
    input string       detail,
    input logic [6:0]  exp_opcode,
    input logic [2:0]  exp_funct3,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_imm,
    input logic [31:0] exp_rs1_data,
    input logic [31:0] exp_rs2_data,
    input logic [31:0] exp_pc
  );
    bit pass;
    pass = (od1_opcode_ex === exp_opcode) && (od1_funct3_ex === exp_funct3) &&
           (od1_rd_ex === exp_rd) && (od1_imm_ex === exp_imm) &&
           (od1_rs1_data_ex === exp_rs1_data) && (od1_rs2_data_ex === exp_rs2_data) &&
           (od1_pc_ex === exp_pc);
    tb_report_open(pass, name, detail);
    tb_field_op7("od1_opcode_ex", od1_opcode_ex, exp_opcode);
    tb_field_f3("od1_funct3_ex", od1_funct3_ex, exp_funct3);
    tb_field_u5("od1_rd_ex", od1_rd_ex, exp_rd);
    tb_field_u32("od1_imm_ex", od1_imm_ex, exp_imm);
    tb_field_u32("od1_rs1_data_ex", od1_rs1_data_ex, exp_rs1_data);
    tb_field_u32("od1_rs2_data_ex", od1_rs2_data_ex, exp_rs2_data);
    tb_field_u32("od1_pc_ex", od1_pc_ex, exp_pc);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    mem0_reg_write = 1'b0;
    mem1_reg_write = 1'b0;
    wb0_reg_write  = 1'b0;
    wb1_reg_write  = 1'b0;
    mem0_rd        = 5'd0;
    mem1_rd        = 5'd0;
    wb0_rd         = 5'd0;
    wb1_rd         = 5'd0;

    tb_banner("id_ex_dispatch_tb - routing, scoreboard, reset/flush");

    // --- Reset clears all lane enables ---
    rst_n = 1'b0;
    flush = 1'b0;
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1000);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1004,
              1'b1, 1'b0);
    tick();
    check_enables("reset_clear", "reset disables all four lane copies",
                  1'b0, 1'b0, 1'b0, 1'b0);
    check_wb_ctrl("reset_wb", "reset clears per-slot WB controls",
                  1'b0, 1'b0, 32'd0, 32'd0);

    rst_n = 1'b1;
    flush = 1'b1;
    tick();
    flush = 1'b0;

    // --- Mixed pair: I0 ADD (even) + I1 LW (odd) -> ev0 + od1 ---
    tick();
    check_enables("dual_mixed_en", "ADD(even)+LW(odd): ev0 and od1 fire",
                  1'b1, 1'b0, 1'b0, 1'b1);
    check_ev0("dual_mixed_ev0", "ev0 carries I0 ADD x1,x2,x3 payload",
              OPC_OP, F3_ADD_SUB, 7'd0, 5'd1, 5'd2, 5'd3,
              32'd0, 32'h11, 32'h22, 32'h1000);
    check_od1("dual_mixed_od1", "od1 carries I1 LW x6,4(x5) payload",
              OPC_LOAD, F3_LW, 5'd6, 32'd4, 32'h2000, 32'h0, 32'h1004);
    check_wb_ctrl("dual_mixed_wb", "both slots reg_write, pc per slot",
                  1'b1, 1'b1, 32'h1000, 32'h1004);

    // --- Even/even pair without same-bundle RAW (distinct rd / rs) ---
    flush_busy();
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1008);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd4, 5'd10, 5'd11, 1'b1, 32'd0, 32'hB0, 32'hB1, 32'h100C);
    tick();
    check_enables("even_pair_en", "ADD+SUB both even: ev0 and ev1 fire",
                  1'b1, 1'b1, 1'b0, 1'b0);
    check_ev1("even_pair_ev1", "ev1 carries I1 SUB x4,x1,x2 payload",
              OPC_OP, F3_ADD_SUB, F7_SUB, 5'd4,
              32'd0, 32'hB0, 32'hB1, 32'h100C);

    // --- Odd/odd pair: I0 LW + I1 SW (store data reg != I0 rd) ---
    flush_busy();
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd7, 5'd5, 5'd0, 1'b1, 32'd8, 32'h3000, 32'h0, 32'h1010,
              1'b1, 1'b0);
    set_slot1(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd5, 5'd12, 1'b0, 32'd12, 32'h3000, 32'hDEAD_BEEF, 32'h1014);
    tick();
    check_enables("odd_pair_en", "LW+SW both odd: od0 and od1 fire",
                  1'b0, 1'b0, 1'b1, 1'b1);
    check_od0("odd_pair_od0", "od0 carries I0 LW x7,8(x5) payload",
              OPC_LOAD, F3_LW, 5'd7, 32'd8, 32'h3000, 32'h0, 32'h1010);
    check_wb_ctrl("odd_pair_wb", "LW writes, SW does not",
                  1'b1, 1'b0, 32'h1010, 32'h1014);

    // --- I1 invalid: only I0 issues ---
    set_slot0(1'b1, LANE_ODD, OPC_JAL, 3'd0, 7'd0,
              5'd1, 5'd0, 5'd0, 1'b1, 32'h100, 32'h0, 32'h0, 32'h1018,
              1'b0, 1'b0);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd9, 5'd1, 5'd2, 1'b1, 32'd0, 32'h0, 32'h0, 32'h101C);
    tick();
    check_enables("i1_invalid_en", "I1 valid=0: only od0 fires",
                  1'b0, 1'b0, 1'b1, 1'b0);
    check_wb_ctrl("i1_invalid_wb", "invalid I1 cannot reg_write",
                  1'b1, 1'b0, 32'h1018, 32'd0);

    // --- Flush clears enables and WB controls ---
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1020);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1024);
    flush = 1'b1;
    tick();
    check_enables("flush_clear", "flush bubbles all four lane copies",
                  1'b0, 1'b0, 1'b0, 1'b0);
    check_wb_ctrl("flush_wb", "flush clears per-slot WB controls",
                  1'b0, 1'b0, 32'd0, 32'd0);

    // --- Capture again after flush ---
    flush = 1'b0;
    tick();
    check_enables("post_flush_en", "pipeline captures again after flush",
                  1'b1, 1'b0, 1'b0, 1'b1);

    // ===================== Edge cases =====================

    // --- I0 invalid, I1 valid: only the slot-1 copy fires ---
    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1028);
    set_slot1(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd9, 5'd4, 5'd0, 1'b1, 32'd7, 32'h90, 32'h0, 32'h102C,
              1'b1, 1'b0);
    tick();
    check_enables("i0_invalid_en", "I0 valid=0: only ev1 fires",
                  1'b0, 1'b1, 1'b0, 1'b0);
    check_wb_ctrl("i0_invalid_wb", "invalid I0 cannot reg_write",
                  1'b0, 1'b1, 32'd0, 32'h102C);

    // --- Both slots invalid: full bubble (pc payload still flows, harmless) ---
    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1030);
    set_slot1(1'b0, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1034);
    tick();
    check_enables("bubble_en", "no valid insn: all four copies idle",
                  1'b0, 1'b0, 1'b0, 1'b0);
    check_wb_ctrl("bubble_wb", "bubble pair cannot reg_write",
                  1'b0, 1'b0, 32'd0, 32'd0);

    // --- Back-to-back pairs: payload swaps every cycle, no stale state ---
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1038);
    set_slot1(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd5, 5'd9, 1'b0, 32'd16, 32'h3000, 32'hF00D, 32'h103C);
    tick();
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd8, 5'd5, 5'd0, 1'b1, 32'd20, 32'h4000, 32'h0, 32'h1040);
    set_slot1(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd9, 5'd5, 5'd0, 1'b1, 32'd1, 32'h99, 32'h0, 32'h1044,
              1'b1, 1'b0);
    tick();
    check_enables("b2b_en", "second pair replaces first with no idle cycle",
                  1'b0, 1'b1, 1'b1, 1'b0);
    check_od0("b2b_od0", "od0 carries second-pair I0 LW x8,20(x5)",
              OPC_LOAD, F3_LW, 5'd8, 32'd20, 32'h4000, 32'h0, 32'h1040);
    check_wb_ctrl("b2b_wb", "WB controls track the newest pair",
                  1'b1, 1'b1, 32'h1040, 32'h1044);

    flush_busy();

    // --- Memory RAR: dual LW same eff. addr -> I1 port only (outline §3) ---
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd6, 5'd0, 1'b1, 32'd0, 32'h1000, 32'h0, 32'h1050);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd7, 5'd0, 1'b1, 32'd0, 32'h1000, 32'h0, 32'h1054);
    tick();
    check_enables("mem_rar_same_en", "RAR same addr: od0 off, od1 on",
                  1'b0, 1'b0, 1'b0, 1'b1);

    // --- Memory WAW: dual SW same eff. addr -> I1 write only (outline §6) ---
    set_slot0(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd5, 5'd6, 1'b0, 32'd0, 32'h2000, 32'hAAA0_AAA6, 32'h1058);
    set_slot1(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd5, 5'd7, 1'b0, 32'd0, 32'h2000, 32'hBBB0_BBB7, 32'h105C);
    tick();
    check_enables("mem_waw_same_en", "WAW same addr: od0 off, od1 on",
                  1'b0, 1'b0, 1'b0, 1'b1);

    // --- Dual LW different eff. addr -> both odd copies on ---
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd6, 5'd0, 1'b1, 32'd0, 32'h1000, 32'h0, 32'h1060);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd7, 5'd0, 1'b1, 32'd0, 32'h2000, 32'h0, 32'h1064);
    tick();
    check_enables("mem_rar_diff_en", "different eff. addr: od0 and od1 on",
                  1'b0, 1'b0, 1'b1, 1'b1);

    // --- LW + SW same addr (mixed): no od0 suppress ---
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd7, 5'd0, 1'b1, 32'd0, 32'h3000, 32'h0, 32'h1068);
    set_slot1(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd6, 5'd7, 1'b0, 32'd0, 32'h3000, 32'hDEAD_BEEF, 32'h106C,
              1'b1, 1'b0);
    tick();
    check_enables("mem_mixed_same_en", "LW+SW same addr: od0 and od1 on",
                  1'b0, 1'b0, 1'b1, 1'b1);

    // --- Contract probe: valid=1 with LANE_NONE ---
    flush_busy();
    set_slot0(1'b1, LANE_NONE, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd3, 5'd1, 5'd2, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1048);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'h0, 32'h0, 32'h104C);
    tick();
    check_enables("lane_none_en", "LANE_NONE routes to no lane copy",
                  1'b0, 1'b0, 1'b0, 1'b0);
    check_wb_ctrl("lane_none_wb", "LANE_NONE cannot reg_write",
                  1'b0, 1'b0, 32'd0, 32'd0);

    // ===================== Scoreboard — same-bundle RAW =====================

    flush_busy();

    // addi x5 | xor uses x5 — cycle 0: I0 only, hold I1
    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd5, 5'd4, 5'd0, 1'b1, 32'd3, 32'h40, 32'h0, 32'h1070,
              1'b1, 1'b0);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd7, 5'd6, 5'd5, 1'b1, 32'd0, 32'h60, 32'h50, 32'h1074);
    tick();
    check_stall("raw_bundle_stall", "same-bundle RAW: stall_id, hold I1",
                1'b1, 1'b1, 1'b1);
    check_enables("raw_bundle_issue_i0", "cycle 0 issues I0 addi only",
                  1'b1, 1'b0, 1'b0, 1'b0);

    // cycle 1: MEM forward for x5 lets held I1 issue
    mem0_reg_write = 1'b1;
    mem0_rd        = 5'd5;
    tick();
    check_stall("raw_bundle_replay", "held I1 issues when forward ready",
                1'b0, 1'b0, 1'b1);
    check_enables("raw_bundle_issue_i1", "cycle 1 issues held xor from ev1",
                  1'b0, 1'b1, 1'b0, 1'b0);
    check_ev1("raw_bundle_ev1", "held I1 xor x7,x6,x5 payload",
              OPC_OP, F3_ADD_SUB, 7'd0, 5'd7,
              32'd0, 32'h60, 32'h50, 32'h1074);
    mem0_reg_write = 1'b0;

    // even | odd inter-dependent: addi x5 | branch uses x5
    flush_busy();
    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd5, 5'd5, 5'd0, 1'b1, 32'd1, 32'h70, 32'h0, 32'h1080,
              1'b1, 1'b0);
    set_slot1(1'b1, LANE_ODD, OPC_BRANCH, F3_BEQ, 7'd0,
              5'd0, 5'd6, 5'd5, 1'b0, 32'd0, 32'h80, 32'h90, 32'h1084);
    tick();
    check_stall("raw_inter_stall", "even|odd same-bundle RAW on x5",
                1'b1, 1'b1, 1'b1);
    check_enables("raw_inter_i0", "branch pair: issue addi on od0 path via ev0",
                  1'b1, 1'b0, 1'b0, 1'b0);

    mem0_reg_write = 1'b1;
    mem0_rd        = 5'd5;
    tick();
    check_enables("raw_inter_i1", "held branch issues on od1",
                  1'b0, 1'b0, 1'b0, 1'b1);
    mem0_reg_write = 1'b0;

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "id_ex_dispatch_tb failed");
    $finish;
  end

endmodule
