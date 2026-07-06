// Parse RV-DIS word hex images (tests/bin/*.hex) into {pc, word} program tables.
// Format: @byte_address then one 32-bit hex word per line (little-endian insn).

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

task automatic imem_load_hex_program(
  input  string              path,
  output imem_prog_entry_t   entries [256],
  output int                 count
);
  int    fd;
  string line;
  logic [31:0] cur_pc;
  logic [31:0] word;
  int    n;

  count  = 0;
  cur_pc = '0;
  fd = $fopen(path, "r");
  if (fd == 0)
    $fatal(1, "imem_load_hex_program: cannot open %s", path);

  while (!$feof(fd)) begin
    n = $fgets(line, fd);
    if (n == 0) break;
    if (line.len() == 0) continue;
    if (imem_line_is_comment(line)) continue;

    if (imem_line_is_addr(line)) begin
      void'($sscanf(line, "@%h", cur_pc));
    end else begin
      if (count >= 256)
        $fatal(1, "imem_load_hex_program: program exceeds 256 entries");
      void'($sscanf(line, "%h", word));
      entries[count].pc   = cur_pc;
      entries[count].word = word;
      count++;
      cur_pc += 32'd4;
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
