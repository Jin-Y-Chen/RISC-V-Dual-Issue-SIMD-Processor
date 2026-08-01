# S3 Rename — testbenches

Directed unit tests for RAT and ROB. Full `rename_core_struct` is **UVM only**.

## Run

```powershell
python sim/run.py alias_table_tb      # RAT + RRAT (alias: rat_tb, allis_table_tb)
python sim/run.py reorder_buffer_tb   # ROB (+ rob units)
python sim/run.py rename_uvm          # rename_core_struct suite
```

## Tests

| Top | DUT | Golden | Config |
|-----|-----|--------|--------|
| `alias_table_tb` | `rtl/s3_rename/core_mod/alias_table.sv` | `model/s3_rename/alias_table_gm.cpp` | `sim/config/s3_rename/alias_table_tb.json` |
| `reorder_buffer_tb` | `rtl/s3_rename/core_mod/reorder_buffer.sv` | `model/s3_rename/rob_gm.cpp` | `sim/config/s3_rename/reorder_buffer_tb.json` |

| Path | Role |
|------|------|
| `tests/` | Directed `*_tb.sv` |
| `../dpi/shims/s3_rename/` | `alias_table_gm.sv`, `reorder_buffer_gm.sv` |
| `../../model/s3_rename/` | C++ DPI goldens |
| `../uvm/rename/` | UVM env for `rename_core_struct` |

## `alias_table_tb` coverage

- Reset / identity maps, `path_use`, x0 / unused sources
- Alloc path0 / path1, dual alloc, same-rd (I1 wins)
- I1 same-path RAW bypass; no cross-path / x0 / I0 self-bypass
- RRAT commit (spec maps unchanged until flush); dual RRAT I1 wins
- `path_sel` copy both directions; younger `rat_en[1]` priority
- Same-cycle path + alloc; flush recovers RRAT
- Hazards: flush vs alloc/RRAT/path; dual RAW; split-path same rd; triple hazard
- ~80-cycle random stress vs GM

## `reorder_buffer_tb` coverage

- Dual / single alloc, WB then retire (no same-cycle WB bypass)
- Store commit (`stb_en`), branch taken / not-taken
- OOO WB with in-order retire; dual store; ALU+branch pair
- Speculative path on/off-path retire; fill-to-stall; flush / realloc

## Notes

- Do **not** add `rename_core_struct_tb`; use `rename_uvm`.
- Legacy `rob_tb` and `rob_*` infra were removed; ROB coverage is `reorder_buffer_tb` only.
- Clock dumps use `clk_edge` = rising/falling via `tb_field_in_clk`.
