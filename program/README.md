# Simulation programs

ASM sources, assembled images for testbenches, and the RV-DIS assembler.

| Folder | Purpose |
|--------|---------|
| `asm/` | Source `.asm` files (`demo_instructions.asm` is the main example) |
| `asm/hazard/`, `asm/dual_issue/`, `asm/simd/` | Placeholders for future programs |
| `bin/` | Assembler output (`.txt`, `.hex`, `.mem`) |
| `assembler/` | [assembler.py](assembler/assembler.py) — [assembler/README.md](assembler/README.md) |

Assemble (from repo root):

```bash
py program/assembler/assembler.py program/asm/demo_instructions.asm
```

Writes `program/bin/demo_instructions.{txt,hex,mem}`.

Load in a testbench:

```verilog
initial $readmemh("program/bin/demo_instructions.hex", imem, 32'h1000 >> 2);
```

Set reset PC to `32'h0000_1000` to match `.org` in the ASM.
