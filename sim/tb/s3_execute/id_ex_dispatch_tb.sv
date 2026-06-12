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
  logic        i1_reg_write_id;
  logic [31:0] i1_imm_id;
  logic [31:0] i1_rs1_data_id;
  logic [31:0] i1_rs2_data_id;
  logic [31:0] i1_pc_id;

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
    input logic [31:0] pc
  );
    i1_valid_id     = valid;
    i1_lane_sel_id  = lane;
    i1_opcode_id    = opcode;
    i1_funct3_id    = funct3;
    i1_funct7_id    = funct7;
    i1_rd_addr_id   = rd;
    i1_rs1_addr_id  = rs1;
    i1_rs2_addr_id  = rs2;
    i1_reg_write_id = reg_write;
    i1_imm_id       = imm;
    i1_rs1_data_id  = rs1_data;
    i1_rs2_data_id  = rs2_data;
    i1_pc_id        = pc;
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

    tb_banner("id_ex_dispatch_tb - fixed slot routing, WB controls, reset/flush");

    // --- Reset clears all lane enables ---
    rst_n = 1'b0;
    flush = 1'b0;
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1000);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1004);
    tick();
    check_enables("reset_clear", "reset disables all four lane copies",
                  1'b0, 1'b0, 1'b0, 1'b0);
    check_wb_ctrl("reset_wb", "reset clears per-slot WB controls",
                  1'b0, 1'b0, 32'd0, 32'd0);

    rst_n = 1'b1;

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

    // --- Even/even pair: I0 ADD + I1 SUB -> ev0 + ev1 (no structural block) ---
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1008);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd4, 5'd1, 5'd2, 1'b1, 32'd0, 32'hB0, 32'hB1, 32'h100C);
    tick();
    check_enables("even_pair_en", "ADD+SUB both even: ev0 and ev1 fire",
                  1'b1, 1'b1, 1'b0, 1'b0);
    check_ev1("even_pair_ev1", "ev1 carries I1 SUB x4,x1,x2 payload",
              OPC_OP, F3_ADD_SUB, F7_SUB, 5'd4,
              32'd0, 32'hB0, 32'hB1, 32'h100C);

    // --- Odd/odd pair: I0 LW + I1 SW -> od0 + od1; SW has no reg_write ---
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd7, 5'd5, 5'd0, 1'b1, 32'd8, 32'h3000, 32'h0, 32'h1010);
    set_slot1(1'b1, LANE_ODD, OPC_STORE, F3_SW, 7'd0,
              5'd0, 5'd5, 5'd7, 1'b0, 32'd12, 32'h3000, 32'hDEAD_BEEF, 32'h1014);
    tick();
    check_enables("odd_pair_en", "LW+SW both odd: od0 and od1 fire",
                  1'b0, 1'b0, 1'b1, 1'b1);
    check_od0("odd_pair_od0", "od0 carries I0 LW x7,8(x5) payload",
              OPC_LOAD, F3_LW, 5'd7, 32'd8, 32'h3000, 32'h0, 32'h1010);
    check_wb_ctrl("odd_pair_wb", "LW writes, SW does not",
                  1'b1, 1'b0, 32'h1010, 32'h1014);

    // --- I1 invalid: only I0 issues ---
    set_slot0(1'b1, LANE_ODD, OPC_JAL, 3'd0, 7'd0,
              5'd1, 5'd0, 5'd0, 1'b1, 32'h100, 32'h0, 32'h0, 32'h1018);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd9, 5'd1, 5'd2, 1'b1, 32'd0, 32'h0, 32'h0, 32'h101C);
    tick();
    check_enables("i1_invalid_en", "I1 valid=0: only od0 fires",
                  1'b0, 1'b0, 1'b1, 1'b0);
    check_wb_ctrl("i1_invalid_wb", "invalid I1 cannot reg_write",
                  1'b1, 1'b0, 32'h1018, 32'h101C);

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

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "id_ex_dispatch_tb failed");
    $finish;
  end

endmodule
