`timescale 1ns / 1ps

import rv_dis_pkg::*;

// Behavioral I$ for simulation (cache_pkg parameterized calls not supported by all simulators).
// Mirrors rtl/s1_fetch/core_mod/instruction_cache.sv: 2048 sets x 4 ways, INDEX_W=13.
// Miss (valid=0) => 32'h0. Preload via preload() / hex image load from TB.
module instruction_cache #(
  parameter int INDEX_W = PC_INDEX_AW,
  parameter int DATA_W  = ILEN,
  parameter int WAYS    = 4
) (
  input  word_t    pc0,
  input  word_t    pc1,
  output instr_t   instr0,
  output instr_t   instr1
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

  function automatic instr_t insn_default(input word_t pc);
    return instr_t'({DATA_W{1'b0}});
  endfunction

  function automatic instr_t way_read(
    input logic [DATA_W:0] way_entry,
    input instr_t          default_data
  );
    return way_entry[DATA_W] ? instr_t'(way_entry[DATA_W-1:0]) : default_data;
  endfunction

  function automatic logic [DATA_W:0] way_pack(input logic valid, input instr_t data);
    return {valid, data[DATA_W-1:0]};
  endfunction

  logic [SET_AW-1:0] i0_set;
  logic [WAY_AW-1:0] i0_way;
  logic [SET_AW-1:0] i1_set;
  logic [WAY_AW-1:0] i1_way;

  assign i0_set = pc_set(pc0);
  assign i0_way = pc_way(pc0);
  assign i1_set = pc_set(pc1);
  assign i1_way = pc_way(pc1);

  // Avoid unpacked-array function args for broader simulator compatibility.
  assign instr0 = (WAYS == 1)
    ? way_read(bank[i0_set][0], insn_default(pc0))
    : way_read(bank[i0_set][i0_way], insn_default(pc0));
  assign instr1 = (WAYS == 1)
    ? way_read(bank[i1_set][0], insn_default(pc1))
    : way_read(bank[i1_set][i1_way], insn_default(pc1));

  initial begin
    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        bank[s][w] = '0;
      end
    end
  end

  task automatic preload(input word_t pc, input instr_t word);
    bank[pc_set(pc)][pc_way(pc)] = way_pack(1'b1, word);
  endtask

  task automatic dump_final(input string path);
    int fd;
    int valid_cnt;
    int pc_index;
    word_t index_pc;

    fd = $fopen(path, "w");
    if (fd == 0) begin
      $error("instruction_cache: cannot open %s for dump", path);
      return;
    end

    $fdisplay(fd, "instruction_cache final state");
    $fdisplay(fd, "INDEX_W=%0d WAYS=%0d SETS=%0d DATA_W=%0d", INDEX_W, WAYS, SETS, DATA_W);
    $fdisplay(fd, "entry format: set way index_pc instruction");
    $fdisplay(fd, "----------------------------------------");

    valid_cnt = 0;
    for (int s = 0; s < SETS; s++) begin
      for (int w = 0; w < WAYS; w++) begin
        if (bank[s][w][DATA_W]) begin
          pc_index = s * WAYS + w;
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
