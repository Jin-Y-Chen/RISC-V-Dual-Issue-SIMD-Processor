# Run logs

`run_yosys.ps1` archives the previous `latest/` tree to `temp/<yyyyMMdd_HHmmss>/` before each run.

```
synth/reports/runs/
  latest/<top>/
    run.log       Yosys stdout
    run.ys        Yosys script
    stat.txt      Yosys stat excerpt
    summary.txt   elab pass/fail (+ sim: with -Sim)
    sim.log       TB self-test output (with -Sim only)
    netlist.v     if -Synth or -SynthRtl
    design.json   if -Synth or -SynthRtl
  temp/<timestamp>/<top>/...
```

Full-chip synth uses folder name `rtl_<top>` (e.g. `rtl_risc_dis_unit`).

Only `.gitkeep` files are tracked; run output is gitignored.
