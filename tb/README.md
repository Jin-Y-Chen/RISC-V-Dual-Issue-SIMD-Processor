# Testbenches

Directed unit TBs, CPU env scaffold, DPI packages, and UVM. Run via:

```powershell
python sim/run.py <top>
python sim/run.py rename_uvm --test rename_smoke_test
python sim/run.py --list
```

See [`sim/README.md`](../sim/README.md). C++ golden models: [`../model/`](../model/).

## Layout

```text
tb/
├── tb_top.sv              // Top-level CPU testbench
├── tb_pkg.sv              // Global types / ROB helpers / txn structs
│
├── interfaces/            // cpu_if, commit_if, memory_if
├── transaction/           // cpu_txn, commit_txn, memory_txn
├── driver/                // cpu_driver, memory_driver, tb_driver (ROB)
├── monitor/               // cpu/commit/memory + tb_monitor (ROB)
├── scoreboard/            // cpu_scoreboard, predictor, tb_scoreboard (ROB)
├── sequence/              // base_seq, random_seq, directed_seq
├── env/                   // cpu_agent, cpu_env, cpu_test
├── dpi/                   // dpi_pkg, cpu_dpi.cpp, tb_console, imem loader
├── rtl/                   // pointers only — design stays in repo rtl/
│
├── uvm/                   // Rename-stage UVM suite
├── top/                   // Full-core directed TB (risc_dis_unit_tb)
│
├── s1_fetch/              // Directed TBs + gm/ DPI shims
├── s2_decode/
├── s3_rename/             // includes rob_tb, reorder_buffer_tb, …
├── s4_dispatch/
├── s5_execute/
├── s6_memory/
└── s7_wback/
```

Stage `gm/` files are thin DPI shims; reference logic lives in `model/<stage>/`.

## Conventions

- `` `include "../dpi/tb_console.svh" ``
- Tick with `@(negedge clk)`; end directed TBs with `tb_summary(...)`.

## UVM

```powershell
python sim/run.py rename_uvm
python sim/run.py rename_uvm --test rename_random_test --sim xsim
```
