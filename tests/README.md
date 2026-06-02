# Test programs

| Folder | Focus |
|--------|--------|
| `asm/` | Basic ISA smoke tests |
| `hazard/` | RAW stalls, forwarding, branch flush |
| `dual_issue/` | Valid even+odd pairs, single-issue, illegal pair stalls |
| `integration/` | Full programs run on CPU TB or FPGA |

Assemble `.asm` sources with `tests/scripts/assembler.py` (writes `tests/bin/<name>.{hex,mem,txt}` — flat, no subfolders).
