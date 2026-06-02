# RV-DIS assembler

```bash
py tests/scripts/assembler.py tests/asm/demo_instructions.asm
```

**Outputs** (flat in `tests/bin/` — temporary build artifacts, no subfolders):

- `demo_instructions.txt`
- `demo_instructions.hex`
- `demo_instructions.mem`

### Vivado IMEM init

```verilog
initial $readmemh("tests/bin/demo_instructions.hex", imem, 32'h1000 >> 2);
```

Reset PC to `32'h0000_1000` to match `.org` in the demo.
