`timescale 1ns / 1ps

// Behavioral BTB for simulation (cache_pkg parameterized calls not supported by Verilator).
// Mirrors rtl/s1_fetch/core_mod/target_buffer.sv: 512 sets x 16 ways, INDEX_W=13.
// Miss (valid=0) => fallthrough(pc+4). WB via i0_valid_wb / i1_valid_wb.
module target_buffer
  import rv_dis_pkg::*;
#(
  parameter int INDEX_W = 13,
  parameter int DATA_W  = 32,
  parameter int WAYS    = 16
) (
  input  word_t    i0_pc,
  input  word_t    i1_pc,
  input  logic     i0_valid_wb,
  input  logic     i1_valid_wb,
  input  word_t    i0_pc_wb,
  input  word_t    i1_pc_wb,
  input  word_t    i0_pc_target_wb,
  input  word_t    i1_pc_target_wb,
  output word_t    i0_pc_target,
  output word_t    i1_pc_target
);

  localparam int WAY_AW = (WAYS == 1) ? 0 : $clog2(WAYS);
  localparam int SET_AW = INDEX_W - WAY_AW;
  localparam int SETS   = (1 << INDEX_W) / WAYS;

  logic [DATA_W:0] bank [SETS][WAYS];

  function automatic logic [SET_AW-1:0] pc_set(input word_t pc);
    return pc[INDEX_W+1 : WAY_AW+2];
  endfunction

  function automatic logic [WAY_AW-1:0] pc_way(input word_t pc);
    if (WAY_AW == 0) return '0;
    return pc[WAY_AW+1:2];
  endfunction

  function automatic word_t fallthrough(input word_t pc);
    return pc + word_t'(32'd4);
  endfunction

  function automatic word_t way_read(
    input logic [DATA_W:0] way_entry,
    input word_t           default_data
  );
    return way_entry[DATA_W] ? word_t'(way_entry[DATA_W-1:0]) : default_data;
  endfunction

  function automatic word_t set_read(
    input logic [DATA_W:0] set_row [WAYS],
    input logic [WAY_AW-1:0] way_idx,
    input word_t default_data
  );
    if (WAYS == 1) return way_read(set_row[0], default_data);
    return way_read(set_row[way_idx], default_data);
  endfunction

  function automatic logic [DATA_W:0] way_pack(input logic valid, input word_t data);
    return {valid, data[DATA_W-1:0]};
  endfunction

  logic [SET_AW-1:0] i0_set;
  logic [WAY_AW-1:0] i0_way;
  logic [SET_AW-1:0] i1_set;
  logic [WAY_AW-1:0] i1_way;

  assign i0_set = pc_set(i0_pc);
  assign i0_way = pc_way(i0_pc);
  assign i1_set = pc_set(i1_pc);
  assign i1_way = pc_way(i1_pc);

  assign i0_pc_target = set_read(bank[i0_set], i0_way, fallthrough(i0_pc));
  assign i1_pc_target = set_read(bank[i1_set], i1_way, fallthrough(i1_pc));

  initial begin
    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        bank[s][w] = '0;
      end
    end
  end

  logic [SET_AW-1:0] wb0_set;
  logic [WAY_AW-1:0] wb0_way;
  logic [SET_AW-1:0] wb1_set;
  logic [WAY_AW-1:0] wb1_way;

  assign wb0_set = pc_set(i0_pc_wb);
  assign wb0_way = pc_way(i0_pc_wb);
  assign wb1_set = pc_set(i1_pc_wb);
  assign wb1_way = pc_way(i1_pc_wb);

  always_comb begin
    if (i0_valid_wb) begin
      bank[wb0_set][wb0_way] = way_pack(1'b1, imm_align4(i0_pc_target_wb));
    end
    if (i1_valid_wb) begin
      bank[wb1_set][wb1_way] = way_pack(1'b1, imm_align4(i1_pc_target_wb));
    end
  end

  // Integration TB helper — same indexing as WB path.
  task automatic install(input word_t pc, input word_t target);
    bank[pc_set(pc)][pc_way(pc)] = way_pack(1'b1, imm_align4(target));
  endtask

  // Dump all valid entries (set, way, index_pc, target) for post-sim inspection.
  task automatic dump_final(input string path);
    int fd;
    int valid_cnt;
    int pc_index;
    word_t index_pc;

    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("target_buffer: cannot open %s for dump", path);
      return;
    end

    $fdisplay(fd, "target_buffer final state");
    $fdisplay(fd, "INDEX_W=%0d WAYS=%0d SETS=%0d DATA_W=%0d", INDEX_W, WAYS, SETS, DATA_W);
    $fdisplay(fd, "entry format: set way index_pc target");
    $fdisplay(fd, "----------------------------------------");

    valid_cnt = 0;
    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        if (bank[s][w][DATA_W]) begin
          pc_index = word_t'(s * WAYS + w);
          index_pc = word_t'(pc_index) << 2;
          $fdisplay(fd, "%0d %0d 0x%08h 0x%08h",
                    s, w, index_pc, bank[s][w][DATA_W-1:0]);
          valid_cnt++;
        end
      end
    end

    $fdisplay(fd, "----------------------------------------");
    $fdisplay(fd, "valid_entries=%0d", valid_cnt);
    $fclose(fd);
  endtask

endmodule
