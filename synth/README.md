# Synthesis outputs

**Yosys** is an RTL synthesis tool: it reads SystemVerilog, builds hierarchy, and produces a structural or gate-level **netlist** (not runnable simulation). In this repo it is used for elaboration checks (`proc`/`opt`), per-module synthesis (`-Synth`), and full-chip synthesis (`-SynthRtl`). A clean run means no `ERROR:` lines in the log — not that a testbench passed.


Generated files are gitignored except `.gitkeep` markers.
