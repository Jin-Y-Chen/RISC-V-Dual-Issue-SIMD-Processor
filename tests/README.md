# Test programs

| Folder | Focus |
|--------|--------|
| `asm/` | Basic ISA smoke tests |
| `hazard/` | RAW stalls, forwarding, branch flush |
| `dual_issue/` | Valid even+odd pairs, single-issue, illegal pair stalls |
| `integration/` | Full programs run on CPU TB or FPGA |

Load machine code via `tools/` (hex/BRAM init) consistent with your memory model.
