`timescale 1ns / 1ps

// forward_unit_tb - WB->EX combinational forwarding (hit, age priority,
// disabled port) and I0->I1 same-cycle falling-edge forward / i1_stall.
module forward_unit_tb;

  import rv_dis_pkg::*;

  `include "../common/tb_console.svh"

  localparam int CLK_PERIOD = 10;

  logic        clk;
  logic        rst_n;

  // Consumer operand ports
  logic        ev0_enable;
  logic [4:0]  ev0_rs1_addr;
  logic [4:0]  ev0_rs2_addr;
  logic [31:0] ev0_rs1_data;
  logic [31:0] ev0_rs2_data;

  logic        ev1_enable;
  logic [4:0]  ev1_rs1_addr;
  logic [4:0]  ev1_rs2_addr;
  logic [31:0] ev1_rs1_data;
  logic [31:0] ev1_rs2_data;

  logic        od0_enable;
  logic [4:0]  od0_rs1_addr;
  logic [4:0]  od0_rs2_addr;
  logic [31:0] od0_rs1_data;
  logic [31:0] od0_rs2_data;

  logic        od1_enable;
  logic [4:0]  od1_rs1_addr;
  logic [4:0]  od1_rs2_addr;
  logic [31:0] od1_rs1_data;
  logic [31:0] od1_rs2_data;

  // I0 producer
  logic        i0_reg_write;
  logic [4:0]  i0_rd_addr;
  logic        ev0_unit_done;
  logic [31:0] ev0_result;
  logic        od0_unit_done;
  logic [31:0] od0_result;

  // WB write ports
  logic        wb0_reg_write;
  logic [4:0]  wb0_rd_addr;
  logic [31:0] wb0_data;
  logic [31:0] wb0_pc;
  logic        wb1_reg_write;
  logic [4:0]  wb1_rd_addr;
  logic [31:0] wb1_data;
  logic [31:0] wb1_pc;

  // Outputs
  logic [31:0] ev0_rs1_data_fwd;
  logic [31:0] ev0_rs2_data_fwd;
  logic [31:0] ev1_rs1_data_fwd;
  logic [31:0] ev1_rs2_data_fwd;
  logic [31:0] od0_rs1_data_fwd;
  logic [31:0] od0_rs2_data_fwd;
  logic [31:0] od1_rs1_data_fwd;
  logic [31:0] od1_rs2_data_fwd;
  logic        i1_stall;

  int pass_cnt;
  int fail_cnt;

  forward_unit dut (.*);

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  task automatic clear_inputs;
    ev0_enable = 1'b0; ev0_rs1_addr = '0; ev0_rs2_addr = '0;
    ev0_rs1_data = '0; ev0_rs2_data = '0;
    ev1_enable = 1'b0; ev1_rs1_addr = '0; ev1_rs2_addr = '0;
    ev1_rs1_data = '0; ev1_rs2_data = '0;
    od0_enable = 1'b0; od0_rs1_addr = '0; od0_rs2_addr = '0;
    od0_rs1_data = '0; od0_rs2_data = '0;
    od1_enable = 1'b0; od1_rs1_addr = '0; od1_rs2_addr = '0;
    od1_rs1_data = '0; od1_rs2_data = '0;
    i0_reg_write = 1'b0; i0_rd_addr = '0;
    ev0_unit_done = 1'b0; ev0_result = '0;
    od0_unit_done = 1'b0; od0_result = '0;
    wb0_reg_write = 1'b0; wb0_rd_addr = '0; wb0_data = '0; wb0_pc = '0;
    wb1_reg_write = 1'b0; wb1_rd_addr = '0; wb1_data = '0; wb1_pc = '0;
  endtask

  // Idle cycle so the negedge latch clears any override left by the last test,
  // then line up on a fresh posedge.
  task automatic next_test;
    clear_inputs();
    @(posedge clk);
    @(posedge clk);
    #1step;
  endtask

  task automatic check_u32(
    input string       name,
    input string       detail,
    input string       label,
    input logic [31:0] got,
    input logic [31:0] exp
  );
    bit pass;
    pass = (got === exp);
    tb_report_open(pass, name, detail);
    tb_field_u32(label, got, exp);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  task automatic check_bit(
    input string name,
    input string detail,
    input string label,
    input logic  got,
    input logic  exp
  );
    bit pass;
    pass = (got === exp);
    tb_report_open(pass, name, detail);
    tb_field_bit(label, got, exp);
    tb_report_close(pass);
    if (pass) pass_cnt++; else fail_cnt++;
  endtask

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    tb_banner("forward_unit_tb - WB->EX forwarding and I0->I1 half-cycle forward");

    clear_inputs();
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1step;

    // --- 1. No hazard: operands pass through unchanged ---
    ev0_enable   = 1'b1;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    ev0_rs2_addr = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    #1;
    check_u32("passthrough_rs1", "no WB hit: ev0 rs1 unchanged",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA);
    check_u32("passthrough_rs2", "no WB hit: ev0 rs2 unchanged",
              "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);
    check_bit("passthrough_stall", "no RAW: i1_stall low",
              "i1_stall", i1_stall, 1'b0);
    next_test();

    // --- 2. WB0 hit replaces only the matching read port ---
    ev0_enable   = 1'b1;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'hDEAD_DEAD;  // stale GPR read
    ev0_rs2_addr = 5'd3;  ev0_rs2_data = 32'h0000_00BB;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32("wb0_hit_rs1", "WB0 x2 hit: ev0 rs1 takes wb0_data",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h1234_5678);
    check_u32("wb0_miss_rs2", "WB0 x2 hit: ev0 rs2 (x3) unaffected",
              "ev0_rs2_data_fwd", ev0_rs2_data_fwd, 32'h0000_00BB);
    next_test();

    // --- 3. WB1 hit on an odd-copy read port ---
    od1_enable   = 1'b1;
    od1_rs1_addr = 5'd4;  od1_rs1_data = 32'h0000_0044;
    od1_rs2_addr = 5'd9;  od1_rs2_data = 32'hDEAD_DEAD;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd9;
    wb1_data = 32'hCAFE_F00D; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb1_hit_od1_rs2", "WB1 x9 hit: od1 rs2 takes wb1_data",
              "od1_rs2_data_fwd", od1_rs2_data_fwd, 32'hCAFE_F00D);
    next_test();

    // --- 4. Both WB ports write same rd: younger pc wins ---
    od0_enable   = 1'b1;
    od0_rs1_addr = 5'd7;  od0_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd7;
    wb0_data = 32'h0000_00C0; wb0_pc = 32'h0000_0100;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd7;
    wb1_data = 32'h0000_00C1; wb1_pc = 32'h0000_0104;
    #1;
    check_u32("wb_double_younger", "wb0/wb1 same rd: younger (wb1) wins",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C1);
    // Swap ages: wb0 is now younger
    wb0_pc = 32'h0000_0104;
    wb1_pc = 32'h0000_0100;
    #1;
    check_u32("wb_double_swapped", "ages swapped: younger (wb0) wins",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C0);
    next_test();

    // --- 5. Disabled consumer: WB hit ignored ---
    ev0_enable   = 1'b0;
    ev0_rs1_addr = 5'd2;  ev0_rs1_data = 32'h0000_00AA;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd2;
    wb0_data = 32'h1234_5678; wb0_pc = 32'h0000_0100;
    #1;
    check_u32("disabled_no_fwd", "ev0 disabled: rs1 passes through",
              "ev0_rs1_data_fwd", ev0_rs1_data_fwd, 32'h0000_00AA);
    next_test();

    // --- 6. I0->I1 RAW, producer done: override after the falling edge ---
    // I0 = ADD x5,... in ev0 (done in first half); I1 = ev1 reads x5.
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd5;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_55AA;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd5;  ev1_rs1_data = 32'hDEAD_DEAD;  // stale GPR read
    ev1_rs2_addr  = 5'd6;  ev1_rs2_data = 32'h0000_0066;
    #1;
    check_u32("i0i1_first_half", "before negedge: ev1 rs1 still stale",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'hDEAD_DEAD);
    check_bit("i0i1_no_stall", "producer done: no replay needed",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("i0i1_second_half", "after negedge: ev1 rs1 takes ev0_result",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_55AA);
    check_u32("i0i1_rs2_intact", "non-RAW port (x6) unaffected",
              "ev1_rs2_data_fwd", ev1_rs2_data_fwd, 32'h0000_0066);
    next_test();

    // --- 7. Odd producer (JAL link) forwards to od1 consumer ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd1;
    od0_unit_done = 1'b1;  od0_result = 32'h0000_1234;   // link_pc
    od1_enable    = 1'b1;
    od1_rs2_addr  = 5'd1;  od1_rs2_data = 32'hDEAD_DEAD;
    @(negedge clk);
    #1step;
    check_u32("od_producer_fwd", "od0 link_pc forwards to od1 rs2",
              "od1_rs2_data_fwd", od1_rs2_data_fwd, 32'h0000_1234);
    next_test();

    // --- 8. RAW with producer not done (LW): i1_stall requests replay ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd8;            // LW x8: data in MEM
    od1_enable    = 1'b1;
    od1_rs1_addr  = 5'd8;  od1_rs1_data = 32'hDEAD_DEAD;
    #1;
    check_bit("lw_raw_stall", "RAW on LW result: i1_stall high",
              "i1_stall", i1_stall, 1'b1);
    @(negedge clk);
    #1step;
    check_u32("lw_raw_no_ovr", "not done: no override latched at negedge",
              "od1_rs1_data_fwd", od1_rs1_data_fwd, 32'hDEAD_DEAD);
    next_test();

    // --- 9. RAW on a different rd: no stall, no override ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd10;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_AAAA;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd11; ev1_rs1_data = 32'h0000_1111; // reads x11, not x10
    #1;
    check_bit("no_raw_no_stall", "rd/rs mismatch: i1_stall low",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("no_raw_no_ovr", "rd/rs mismatch: ev1 rs1 unchanged",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_1111);
    next_test();

    // ===================== Edge cases =====================

    // --- 10. Both WB ports, equal pc: tie resolves to wb1 (>= compare) ---
    od0_enable   = 1'b1;
    od0_rs1_addr = 5'd7;  od0_rs1_data = 32'hDEAD_DEAD;
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd7;
    wb0_data = 32'h0000_00C0; wb0_pc = 32'h0000_0100;
    wb1_reg_write = 1'b1; wb1_rd_addr = 5'd7;
    wb1_data = 32'h0000_00C1; wb1_pc = 32'h0000_0100;
    #1;
    check_u32("wb_pc_tie", "equal WB pc: tie goes to wb1",
              "od0_rs1_data_fwd", od0_rs1_data_fwd, 32'h0000_00C1);
    next_test();

    // --- 11. I0 override outranks a WB hit on the same register (EX newer) ---
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd5;
    wb0_data = 32'h0000_0BAD; wb0_pc = 32'h0000_0100;  // older value of x5
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd5;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_600D; // newest value of x5
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd5;  ev1_rs1_data = 32'hDEAD_DEAD;
    #1;
    check_u32("ovr_vs_wb_half1", "first half: WB value bridges the gap",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_0BAD);
    @(negedge clk);
    #1step;
    check_u32("ovr_vs_wb_half2", "second half: I0 result outranks WB hit",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_600D);
    next_test();

    // --- 12. RAW on both rs1 and rs2 of the same consumer ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd4;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_4444;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd4;  ev1_rs1_data = 32'hDEAD_DEAD;
    ev1_rs2_addr  = 5'd4;  ev1_rs2_data = 32'hDEAD_DEAD;
    #1;
    check_bit("dual_raw_no_stall", "both ports RAW, producer done: no stall",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("dual_raw_rs1", "rs1 takes I0 result",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_4444);
    check_u32("dual_raw_rs2", "rs2 takes I0 result",
              "ev1_rs2_data_fwd", ev1_rs2_data_fwd, 32'h0000_4444);
    next_test();

    // --- 13. unit_done without reg_write (no GPR producer): no override ---
    i0_reg_write  = 1'b0;  i0_rd_addr = 5'd6;
    ev0_unit_done = 1'b1;  ev0_result = 32'hBAD0_BAD0;
    od1_enable    = 1'b1;
    od1_rs1_addr  = 5'd6;  od1_rs1_data = 32'h0000_0606;
    #1;
    check_bit("no_rw_no_stall", "address match but i0_reg_write=0: no stall",
              "i1_stall", i1_stall, 1'b0);
    @(negedge clk);
    #1step;
    check_u32("no_rw_no_ovr", "no GPR producer: od1 rs1 unchanged",
              "od1_rs1_data_fwd", od1_rs1_data_fwd, 32'h0000_0606);
    next_test();

    // --- 14. RAW address match but consumer disabled: no stall ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd8;     // not done (LW-like)
    od1_enable    = 1'b0;
    od1_rs1_addr  = 5'd8;  od1_rs1_data = 32'hDEAD_DEAD;
    #1;
    check_bit("disabled_no_stall", "consumer disabled: RAW ignored, no stall",
              "i1_stall", i1_stall, 1'b0);
    next_test();

    // --- 15. Stale override leak: back-to-back pairs on the same register.
    //     Cycle A latches an override for x12; cycle B issues an independent
    //     I1 reading x12 with fresh GPR data and no RAW. The flag only
    //     recomputes at cycle B's negedge, so the first half-cycle can show
    //     cycle A's result. Lanes are sampled at posedge after settle, so
    //     this is benign for data - probe and report it. ---
    i0_reg_write  = 1'b1;  i0_rd_addr = 5'd12;
    ev0_unit_done = 1'b1;  ev0_result = 32'h0000_C0DE;
    ev1_enable    = 1'b1;
    ev1_rs1_addr  = 5'd12; ev1_rs1_data = 32'hDEAD_DEAD;
    @(negedge clk);
    #1step;                                       // cycle A: override latched
    i0_reg_write  = 1'b0;
    ev0_unit_done = 1'b0;
    ev1_rs1_data  = 32'h0000_7777;                // cycle B: fresh, no RAW
    @(posedge clk);
    #1;
    if (ev1_rs1_data_fwd !== 32'h0000_7777) begin
      tb_warn_msg($sformatf(
        "stale override in first half-cycle: ev1_rs1_data_fwd=0x%08h (fresh value 0x00007777)",
        ev1_rs1_data_fwd));
      tb_info_msg("benign for registered consumers; combinational uses (e.g. brch_taken) would glitch in the first half");
    end else begin
      tb_info_msg("no stale first-half override observed");
    end
    @(negedge clk);
    #1step;
    check_u32("stale_ovr_recovers", "second half: flag recomputed, fresh operand",
              "ev1_rs1_data_fwd", ev1_rs1_data_fwd, 32'h0000_7777);
    next_test();

    // --- 16. Contract probe: WB write to x0 (decode_reg_write gates rd==x0,
    //     so this never reaches the forward unit). fwd_port has no x0 check;
    //     observe whether a forged x0 write would corrupt an x0 read. ---
    ev0_enable   = 1'b1;
    ev0_rs1_addr = 5'd0;  ev0_rs1_data = 32'h0000_0000;  // x0 reads as 0
    wb0_reg_write = 1'b1; wb0_rd_addr = 5'd0;
    wb0_data = 32'hBAD0_BAD0; wb0_pc = 32'h0000_0100;
    #1;
    if (ev0_rs1_data_fwd !== 32'h0000_0000) begin
      tb_warn_msg("x0 probe: forged WB write to x0 forwards onto an x0 read");
      tb_info_msg("safe only because decode_reg_write forces reg_write=0 for rd==x0");
    end else begin
      tb_info_msg("x0 probe: x0 read stays zero under WB write to x0");
    end

    $display("");
    tb_summary(pass_cnt, fail_cnt);
    if (fail_cnt != 0)
      $fatal(1, "forward_unit_tb failed");
    $finish;
  end

endmodule
