// Parse RV-DIS byte IMEM images (*.mem) into {pc, word} program tables.
// Format matches Vivado $readmemh: @byte_address then one 8-bit hex byte per line
// (little-endian insn words: bytes at pc+0..pc+3).
//
// Path search: explicit path, +imem_mem=<path>, then common repo / Vivado locations.

typedef struct packed {
  logic [31:0] pc;
  logic [31:0] word;
} imem_prog_entry_t;

function automatic bit imem_line_is_comment(input string line);
  return (line.len() >= 2) && (line[0] == "/") && (line[1] == "/");
endfunction

function automatic bit imem_line_is_addr(input string line);
  return (line.len() >= 1) && (line[0] == "@");
endfunction

function automatic word_t imem_le_word(
  input logic [7:0] b0,
  input logic [7:0] b1,
  input logic [7:0] b2,
  input logic [7:0] b3
);
  return word_t'({b3, b2, b1, b0});
endfunction

function automatic bit imem_file_readable(input string path);
  int fd;
  if (path.len() == 0)
    return 1'b0;
  fd = $fopen(path, "r");
  if (fd == 0)
    return 1'b0;
  $fclose(fd);
  return 1'b1;
endfunction

// Try hint, then standard repo-root and Vivado co-import locations.
function automatic string imem_resolve_mem_path(input string hint);
  string candidates [$];
  int    n;
  int    i;

  candidates.push_back(hint);
  if (hint != "demo_instructions.mem")
    candidates.push_back("demo_instructions.mem");
  if (hint != "program/bin/demo_instructions.mem")
    candidates.push_back("program/bin/demo_instructions.mem");
  candidates.push_back("tb/s1_fetch/demo_instructions.mem");
  candidates.push_back("../demo_instructions.mem");
  candidates.push_back("../../program/bin/demo_instructions.mem");
  candidates.push_back("../../../program/bin/demo_instructions.mem");

  n = candidates.size();
  for (i = 0; i < n; i++) begin
    if (imem_file_readable(candidates[i]))
      return candidates[i];
  end
  return hint;
endfunction

task automatic imem_load_mem_program(
  input  string              path,
  output imem_prog_entry_t   entries [256],
  output int                 count
);
  int          fd;
  string       line;
  string       resolved;
  logic [31:0] cur_pc;
  logic [7:0]  bytes [0:3];
  int          byte_idx;
  int          n;
  int          got;

  count    = 0;
  cur_pc   = '0;
  byte_idx = 0;
  resolved = imem_resolve_mem_path(path);
  fd = $fopen(resolved, "r");
  if (fd == 0) begin
    $display("[imem] tried hint '%s' and fallback paths; none opened", path);
    $fatal(1, "imem_load_mem_program: cannot open %s", path);
  end
  if (resolved != path)
    $display("[imem] opened '%s' (hint was '%s')", resolved, path);

  while (!$feof(fd)) begin
    n = $fgets(line, fd);
    if (n == 0) break;
    if (line.len() == 0) continue;
    if (imem_line_is_comment(line)) continue;

    if (imem_line_is_addr(line)) begin
      void'($sscanf(line, "@%h", cur_pc));
      byte_idx = 0;
    end else begin
      got = $sscanf(line, "%hhx", bytes[byte_idx]);
      if (got != 1) continue;
      byte_idx++;
      if (byte_idx == 4) begin
        if (count >= 256)
          $fatal(1, "imem_load_mem_program: program exceeds 256 entries");
        if (cur_pc[1:0] != 2'b00)
          $fatal(1, "imem_load_mem_program: unaligned word PC 0x%08h in %s",
                 cur_pc, resolved);
        entries[count].pc   = cur_pc;
        entries[count].word = imem_le_word(bytes[0], bytes[1], bytes[2], bytes[3]);
        count++;
        cur_pc   += 32'd4;
        byte_idx  = 0;
      end
    end
  end

  $fclose(fd);
endtask

function automatic logic [31:0] imem_lookup(
  input imem_prog_entry_t entries [256],
  input int                 count,
  input logic [31:0]          pc
);
  logic [31:0] key;
  key = {pc[31:2], 2'b00};
  for (int i = 0; i < count; i++) begin
    if (entries[i].pc == key)
      return entries[i].word;
  end
  return 32'h0;
endfunction
