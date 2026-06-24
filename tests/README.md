# Test programs

ASM sources for instruction smoke tests and future integration runs.

| Folder | Purpose |
|--------|---------|
| `asm/` | Source `.asm` files (`demo_instructions.asm` is the main example) |
| `asm/hazard/`, `asm/dual_issue/`, `asm/simd/` | Placeholders for future tests |
| `bin/` | Assembler output (gitignored except checked-in demo artifacts) |
| `scripts/` | [assembler.py](scripts/assembler.py) — [scripts/README.md](scripts/README.md) |

Assemble:

```bash
py tests/scripts/assembler.py tests/asm/demo_instructions.asm
```

Writes `tests/bin/demo_instructions.{txt,hex,mem}`.
