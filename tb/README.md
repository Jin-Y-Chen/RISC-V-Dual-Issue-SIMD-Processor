# Testbenches

Run from repo root:

```bash
./scripts/run-sim -TOP <name>
```

```powershell
.\scripts\lib\run_yosys.ps1 -Top <name> -Sim
```

Shared utilities: `common/` (`tb_console.svh`, `tb_block_case_loader.svh`). See `common/README.md`.

Golden models: `gm/` (Verilog, sim) + `tb/gm/` (C++ offline check). See `model/README.md`.

## Conventions (WSL)

- **`tb_advance(clk)`** — `tick` tasks call `@(negedge clk)`; use `always #(CLK_PERIOD/2)` for the clock (not `initial forever`, which can hang some simulators with timing enabled).
- **Includes** — `` `include "../common/tb_console.svh" `` from `tb/<stage>/*_tb.sv`; paths stay relative to the TB file (`--relative-includes` in the driver).
- **`tb_summary`** — end every TB with `tb_summary(pass_cnt, fail_cnt)` so `sim.log` prints `*** SUMMARY ***`.

```
tb/
  common/         tb_console.svh, tb_block_case_loader.svh, imem_hex_loader.svh
  models/         (future BFMs / memory models)
  s1_fetch/
    cases/        *.txt case data
    pc_tb, pc_selector_tb, instruction_cache_tb, target_buffer_tb, fetch_core_struct_tb
  s2_decode/      if_id_tb, decoder_tb, state_buffer_tb, register_file_tb
  s3_execute/     even_lane_tb, odd_lane_tb, id_ex_dispatch_tb,
                  forward_unit_tb, scoreboard_tb
  s4_memory/      ex_mem_tb, memory_cache_tb
  s5_wback/       ex_mem_wb_tb
```

## s1_fetch

| TB | DUT | Checks |
|----|-----|--------|
| `pc_tb` | `rtl/s1_fetch/pc.sv` | Reset, +8/+8, +4/+4, stall, enable hold |
| `pc_selector_tb` | `rtl/s1_fetch/core_mod/pc_selector.sv` | Predict / recover / stall-in-spec |
| `instruction_cache_tb` | `tb/s1_fetch/models/instruction_cache.sv` | Dual read, miss → 0 |
| `target_buffer_tb` | `tb/s1_fetch/models/target_buffer.sv` | Miss → pc+4, WB install hit |
| `fetch_core_struct_tb` | `rtl/s1_fetch/fetch_core_struct.sv` (+ real `pc` / `pc_selector`, sim I$/BTB models) | Sequential, BTB, predict, stall, recover |

I$/BTB sim lists use behavioral models in `tb/s1_fetch/models/` because `cache_pkg` parameterized functions are not supported by all simulators. Real RTL remains under `rtl/s1_fetch/core_mod/`.

## s2_decode

| TB | DUT | Checks |
|----|-----|--------|
| `if_id_tb` | `rtl/s2_decode/if_id.sv` | IF/ID register |
| `decoder_tb` | `rtl/s2_decode/core/decoder.sv` | opcode, imm, `lane_sel`, reg flags |
| `state_buffer_tb` | `rtl/s2_decode/branch/state_buffer.sv` | branch predictor state |
| `register_file_tb` | `rtl/s2_decode/core/register_file.sv` | x0, dual WB, bypass, 4 read ports |

## s3_execute

| TB | DUT | Checks |
|----|-----|--------|
| `even_lane_tb` | `even_lane.sv` + `scalar_alu.sv` | ADD/SUB/AND/OR/XOR |
| `odd_lane_tb` | `odd_lane.sv`, branch + LSU | branches, JAL/JALR, LW/SW |
| `id_ex_dispatch_tb` | `rtl/s3_dispatch/dispatch_core_struct.sv` | even/odd dispatch |
| `forward_unit_tb` | `rtl/s3_execution/core/forward_unit.sv` | EX/MEM/WB forward mux |
| `scoreboard_tb` | `rtl/s3_execution/dispatch_funct/scoreboard.sv` | RAW / stall |

## s4_memory

| TB | DUT | Checks |
|----|-----|--------|
| `ex_mem_tb` | `rtl/s4_memory/ex_mem.sv` | per-lane EX/MEM, stall, flush |
| `memory_cache_tb` | `rtl/s4_memory/core/memory_cache.sv` | D-cache |

## s5_wback

| TB | DUT | Checks |
|----|-----|--------|
| `ex_mem_wb_tb` | `rtl/s5_wback/ex_mem_wb.sv` | 4 lane inputs → 2 GPR writes |

## Not in tree yet

`dispatch_hazard_tb` — listed in `run_yosys.ps1` `-Top` validate set but no `tb/s2_decode/dispatch_hazard_tb.sv` file.

Design context: [../../project_outline.txt](../../project_outline.txt)
