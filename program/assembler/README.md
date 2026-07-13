# Assembler

```bash
py program/assembler/assembler.py program/asm/demo_instructions.asm
```

Output (flat under `program/bin/`):

- `demo_instructions.txt` — listing
- `demo_instructions.hex` — hex words
- `demo_instructions.mem` — `$readmemh` format

Load in a testbench:

```verilog
initial $readmemh("program/bin/demo_instructions.hex", imem, 32'h1000 >> 2);
```

Set reset PC to `32'h0000_1000` to match `.org` in the ASM.
