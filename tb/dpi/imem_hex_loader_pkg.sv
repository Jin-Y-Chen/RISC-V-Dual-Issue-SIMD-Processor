`timescale 1ns / 1ps

// Vivado $readmemh byte .mem -> {pc, word} table (LE words). +imem_mem=<path> or fallbacks.
package imem_hex_loader_pkg;

  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] word;
  } imem_prog_entry_t;

  function automatic string imem_resolve_mem_path(input string hint);
    string paths[$];
    int    fd;
    paths = '{hint, "demo_instructions.mem", "program/bin/demo_instructions.mem",
              "tb/s1_fetch/demo_instructions.mem", "../demo_instructions.mem",
              "../../program/bin/demo_instructions.mem", "../../../program/bin/demo_instructions.mem"};
    foreach (paths[i]) begin
      if (paths[i].len() != 0) begin
        fd = $fopen(paths[i], "r");
        if (fd != 0) begin
          $fclose(fd);
          return paths[i];
        end
      end
    end
    return hint;
  endfunction

  task automatic imem_load_mem_program(
    input  string            path,
    output imem_prog_entry_t entries [256],
    output int               count
  );
    int          fd;
    string       line, resolved;
    logic [31:0] cur_pc;
    logic [7:0]  bytes [0:3];
    int          byte_idx;

    count = 0; cur_pc = '0; byte_idx = 0;
    resolved = imem_resolve_mem_path(path);
    fd = $fopen(resolved, "r");
    if (fd == 0)
      $fatal(1, "imem_load_mem_program: cannot open %s (hint '%s')", resolved, path);
    if (resolved != path)
      $display("[imem] opened '%s' (hint was '%s')", resolved, path);

    while (!$feof(fd)) begin
      if ($fgets(line, fd) == 0) break;
      if (line.len() == 0) continue;
      if (line.len() >= 2 && line[0] == "/" && line[1] == "/") continue;
      if (line[0] == "@") begin
        void'($sscanf(line, "@%h", cur_pc));
        byte_idx = 0;
      end else if ($sscanf(line, "%hhx", bytes[byte_idx]) == 1) begin
        if (++byte_idx == 4) begin
          if (count >= 256)
            $fatal(1, "imem_load_mem_program: program exceeds 256 entries");
          if (cur_pc[1:0] != 2'b00)
            $fatal(1, "imem_load_mem_program: unaligned PC 0x%08h in %s", cur_pc, resolved);
          entries[count].pc   = cur_pc;
          entries[count].word = {bytes[3], bytes[2], bytes[1], bytes[0]};
          count++;
          cur_pc += 32'd4;
          byte_idx = 0;
        end
      end
    end
    $fclose(fd);
  endtask

endpackage
