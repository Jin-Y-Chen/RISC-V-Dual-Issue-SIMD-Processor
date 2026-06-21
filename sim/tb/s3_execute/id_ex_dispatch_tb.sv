`timescale 1ns / 1ps

// id_ex_dispatch_tb - dispatch ID/EX per project_outline sec 1, sec 3, sec 4 (RAW + stall_id).
// Each check logs all driven ID control inputs and observed EX control outputs.
module id_ex_dispatch_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;
  logic        enable;
  logic        flush;

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
    @(posedge clk);
    #1step;
  endtask

  function automatic string lane_name(input lane_sel_e lane);
    case (lane)
      LANE_EVEN: lane_name = "EVEN";
      LANE_ODD:  lane_name = "ODD";
      LANE_NONE: lane_name = "NONE";
      default:   lane_name = $sformatf("%0d", lane);
    endcase
  endfunction

  task automatic log_val_bit(input string label, input logic val);
    $display("  %-16s = %0d", label, val);
  endtask

  task automatic log_val_lane(input string label, input lane_sel_e val);
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
    log_val_bit("i0_valid_id", i0_valid_id);
    log_val_lane("i0_lane_sel_id", i0_lane_sel_id);
    log_val_op7("i0_opcode_id", i0_opcode_id);
    log_val_u5("i0_rd_addr_id", i0_rd_addr_id);
    log_val_u5("i0_rs1_addr_id", i0_rs1_addr_id);
    log_val_u5("i0_rs2_addr_id", i0_rs2_addr_id);
    log_val_bit("i0_reg_write_id", i0_reg_write_id);
    log_val_u32("i0_pc_id", i0_pc_id);
    log_val_bit("i1_valid_id", i1_valid_id);
    log_val_lane("i1_lane_sel_id", i1_lane_sel_id);
    log_val_op7("i1_opcode_id", i1_opcode_id);
    log_val_u5("i1_rd_addr_id", i1_rd_addr_id);
    log_val_u5("i1_rs1_addr_id", i1_rs1_addr_id);
    log_val_u5("i1_rs2_addr_id", i1_rs2_addr_id);
    log_val_bit("i1_rs1_use_id", i1_rs1_use_id);
    log_val_bit("i1_rs2_use_id", i1_rs2_use_id);
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

  task automatic flush_busy;
    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0,
              1'b0, 1'b0);
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

    tb_banner("id_ex_dispatch_tb - project_outline sec 1/3/4 lane, structure, RAW/stall");

    // ------------------------------------------------------------------
    section_banner("Reset / flush");
    // ------------------------------------------------------------------

    rst_n  = 1'b0;
    enable = 1'b1;
    flush  = 1'b0;
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1000);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1004,
              1'b1, 1'b0);
    tick();
    check_case("reset_clear", "active-low reset clears EX control outputs",
               "reset", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);

    rst_n = 1'b1;
    flush = 1'b1;
    tick();
    flush = 1'b0;

    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h11, 32'h22, 32'h1020);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h2000, 32'h0, 32'h1024);
    flush = 1'b1;
    tick();
    check_case("flush_bubble", "flush bubbles all lane enables and WB controls",
               "flush", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);
    flush = 1'b0;

    // ------------------------------------------------------------------
    section_banner("sec 1 Lane map - clean even|odd pair, no stall");
    // ------------------------------------------------------------------

    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd5, 5'd0, 1'b1, 32'h2C, 32'h40, 32'h0, 32'h1100);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd2, 5'd5, 5'd0, 1'b1, 32'd0, 32'h50, 32'h0, 32'h1104,
              1'b1, 1'b0);
    tick();
    check_case("lane_clean_even_odd",
               "addi x1,x5,0x2c | lw x2,0(x5): ev0+od1, stall_id=0",
               "sec 1 clean pair", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1,
               1'b1, 1'b1, 32'h1100, 32'h1104);

    // ------------------------------------------------------------------
    section_banner("sec 3 Structure hazard - same lane type, no stall");
    // ------------------------------------------------------------------

    flush_busy();
    set_slot0(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'hA0, 32'hA1, 32'h1200);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, F7_SUB,
              5'd4, 5'd10, 5'd11, 1'b1, 32'd0, 32'hB0, 32'hB1, 32'h1204);
    tick();
    check_case("struct_even_even",
               "add x1,x2,x3 | sub x4,x5,x6: ev0+ev1 parallel, stall_id=0",
               "sec 3b even|even", 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
               1'b1, 1'b1, 32'h1200, 32'h1204);

    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'd0, 32'hC0, 32'h0, 32'h1208);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd3, 5'd4, 5'd0, 1'b1, 32'd0, 32'hD0, 32'h0, 32'h120C);
    tick();
    check_case("struct_odd_odd",
               "lw x1,0(x2) | lw x3,0(x4): od0+od1 parallel, stall_id=0",
               "sec 3b odd|odd", 1'b0, 1'b0, 1'b0, 1'b1, 1'b1,
               1'b1, 1'b1, 32'h1208, 32'h120C);

    // ------------------------------------------------------------------
    section_banner("Validity / routing edge cases");
    // ------------------------------------------------------------------

    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1300);
    set_slot1(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd9, 5'd4, 5'd0, 1'b1, 32'd7, 32'h90, 32'h0, 32'h1304,
              1'b1, 1'b0);
    tick();
    check_case("i0_invalid", "I0 valid=0: only ev1 issues",
               "valid gating", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
               1'b0, 1'b1, 32'd0, 32'h1304);

    set_slot0(1'b1, LANE_ODD, OPC_JAL, 3'd0, 7'd0,
              5'd1, 5'd0, 5'd0, 1'b1, 32'h100, 32'h0, 32'h0, 32'h1308);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'h0, 32'h0, 32'h130C,
              1'b0, 1'b0);
    tick();
    check_case("i1_invalid", "I1 valid=0: only od0 issues",
               "valid gating", 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
               1'b1, 1'b0, 32'h1308, 32'd0);

    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd3, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1310);
    set_slot1(1'b0, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd6, 5'd5, 5'd0, 1'b1, 32'd4, 32'h0, 32'h0, 32'h1314);
    tick();
    check_case("bubble", "both invalid: full bubble, stall_id=0",
               "valid gating", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);

    set_slot0(1'b1, LANE_NONE, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd3, 5'd1, 5'd2, 1'b1, 32'd0, 32'h0, 32'h0, 32'h1318);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'h0, 32'h0, 32'h131C);
    tick();
    check_case("lane_none", "LANE_NONE never routes to a lane copy",
               "lane gating", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);

    // ------------------------------------------------------------------
    section_banner("sec 4.d.1 RAW - 1-cycle stall (ALU producer, stall_id=1)");
    // ------------------------------------------------------------------

    flush_busy();

    // even|even intra-dependent: addi x5,x4,x3 | xor x7,x6,x5
    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd5, 5'd4, 5'd0, 1'b1, 32'd3, 32'h40, 32'h0, 32'h2000);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd7, 5'd6, 5'd5, 1'b1, 32'd0, 32'h60, 32'h50, 32'h2004);
    tick();
    check_case("raw_d1_even_even_c0",
               "capture: partial-issue I0, buffer I1, stall_id=1",
               "sec 4.d.1 even|even", 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
               1'b1, 1'b0, 32'h2000, 32'd0);

    tick();
    tick();
    check_case("raw_d1_even_even_c1_replay",
               "replay: held xor on ev1, stall_id=0 (wait_cnt reached 1)",
               "sec 4.d.1 even|even", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
               1'b0, 1'b1, 32'd0, 32'h2004);

    tick();
    check_case("raw_d1_even_even_c2_suppress",
               "same PCs linger: suppress_bundle_raw, stall_id=0, dual issue",
               "sec 4.d.1 suppress", 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
               1'b1, 1'b1, 32'h2000, 32'h2004);

    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd8, 5'd4, 5'd0, 1'b1, 32'd3, 32'h40, 32'h0, 32'h2010);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd9, 5'd6, 5'd8, 1'b1, 32'd0, 32'h60, 32'h50, 32'h2014);
    tick();
    check_case("raw_d1_even_even_c3_new_pc",
               "PC advance clears suppress; fresh RAW stalls again",
               "sec 4.d.1 suppress clear", 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
               1'b1, 1'b0, 32'h2010, 32'd0);

    flush_busy();

    // even|odd inter-dependent: addi x5,x5,1 | brne x6,x5,label
    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd5, 5'd5, 5'd0, 1'b1, 32'd1, 32'h70, 32'h0, 32'h2100);
    set_slot1(1'b1, LANE_ODD, OPC_BRANCH, F3_BNE, 7'd0,
              5'd0, 5'd6, 5'd5, 1'b0, 32'd0, 32'h80, 32'h90, 32'h2104);
    tick();
    check_case("raw_d1_even_odd_c0",
               "capture: ev0 only, buffer branch on od1, stall_id=1",
               "sec 4.d.1 even|odd", 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
               1'b1, 1'b0, 32'h2100, 32'd0);

    tick();
    tick();
    check_case("raw_d1_even_odd_replay",
               "replay: held branch on od1, stall_id=0",
               "sec 4.d.1 even|odd", 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
               1'b0, 1'b0, 32'd0, 32'h2104);

    // ------------------------------------------------------------------
    section_banner("sec 4.d.2 RAW - 2-cycle stall (load producer, stall_id=1)");
    // ------------------------------------------------------------------

    flush_busy();

    // odd|even inter-dependent: lw x2,0(x5) | addi x1,x2,0x2c
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd2, 5'd5, 5'd0, 1'b1, 32'd0, 32'hA0, 32'h0, 32'h2200);
    set_slot1(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd1, 5'd2, 5'd0, 1'b1, 32'h2C, 32'h0, 32'h0, 32'h2204);
    tick();
    check_case("raw_d2_odd_even_c0",
               "capture: od0 only, buffer addi, stall_id=1",
               "sec 4.d.2 odd|even", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0,
               1'b1, 1'b0, 32'h2200, 32'd0);

    tick();
    check_case("raw_d2_odd_even_c1",
               "wait cycle 1: stall_id=1, lw held in EX",
               "sec 4.d.2 odd|even", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0,
               1'b1, 1'b0, 32'h2200, 32'd0);

    tick();
    tick();
    check_case("raw_d2_odd_even_replay",
               "replay: held addi on ev1, stall_id=0 (2-cycle load-use wait done)",
               "sec 4.d.2 odd|even", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
               1'b0, 1'b1, 32'd0, 32'h2204);

    flush_busy();

    // odd|odd intra-dependent: lw x2,0(x5) | lw x5,0(x2)
    set_slot0(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd2, 5'd5, 5'd0, 1'b1, 32'd0, 32'hB0, 32'h0, 32'h2300);
    set_slot1(1'b1, LANE_ODD, OPC_LOAD, F3_LW, 7'd0,
              5'd5, 5'd2, 5'd0, 1'b1, 32'd0, 32'h0, 32'h0, 32'h2304);
    tick();
    check_case("raw_d2_odd_odd_c0",
               "capture: od0 only, buffer second lw, stall_id=1",
               "sec 4.d.2 odd|odd", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0,
               1'b1, 1'b0, 32'h2300, 32'd0);

    tick();
    tick();
    tick();
    check_case("raw_d2_odd_odd_replay",
               "replay: held lw on od1, stall_id=0",
               "sec 4.d.2 odd|odd", 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
               1'b0, 1'b1, 32'd0, 32'h2304);

    // ------------------------------------------------------------------
    section_banner("Flush clears I1 buffer before replay");
    // ------------------------------------------------------------------

    flush_busy();
    set_slot0(1'b1, LANE_EVEN, OPC_OP_IMM, F3_ADD_SUB, 7'd0,
              5'd5, 5'd4, 5'd0, 1'b1, 32'd3, 32'h40, 32'h0, 32'h2400);
    set_slot1(1'b1, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd7, 5'd6, 5'd5, 1'b1, 32'd0, 32'h60, 32'h50, 32'h2404);
    tick();
    check_case("flush_hold_set",
               "RAW capture latched; stall_id=1 before flush",
               "sec 4.d.1 + flush", 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
               1'b1, 1'b0, 32'h2400, 32'd0);

    flush = 1'b1;
    tick();
    flush = 1'b0;
    set_slot0(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0);
    set_slot1(1'b0, LANE_EVEN, OPC_OP, F3_ADD_SUB, 7'd0,
              5'd0, 5'd0, 5'd0, 1'b0, 32'd0, 32'd0, 32'd0, 32'd0,
              1'b0, 1'b0);
    tick();
    check_case("flush_hold_clear",
               "flush drops buffered I1; stall_id=0, no replay",
               "sec 4.d.1 + flush", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
               1'b0, 1'b0, 32'd0, 32'd0);

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "id_ex_dispatch_tb failed");
    $finish;
  end

endmodule
