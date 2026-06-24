# Assembler

```bash
py tests/scripts/assembler.py tests/asm/demo_instructions.asm
```

Output (flat under `tests/bin/`):

- `demo_instructions.txt` — listing
- `demo_instructions.hex` — hex words
- `demo_instructions.mem` — `$readmemh` format

Load in a testbench:

```verilog
initial $readmemh("tests/bin/demo_instructions.hex", imem, 32'h1000 >> 2);
```

Set reset PC to `32'h0000_1000` to match `.org` in the ASM.
