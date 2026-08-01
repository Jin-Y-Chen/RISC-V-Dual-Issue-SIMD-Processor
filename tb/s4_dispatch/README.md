# S4 Dispatch / issue — testbenches

Peer cores under `issue_core_struct`:

```text
issue_core_struct
  ├── reservation_station   bank + wakeup + alloc
  ├── bypass_unit           same-cycle dispatch ready/age
  ├── selector_unit         oldest-ready pick (+ rs_issue)
  └── p_register_file       physical RF
```

Each core has its own directed TB (no monolithic issue smoke).

## Run

```powershell
python sim/run.py bypass_tb
python sim/run.py selector_tb
python sim/run.py reservation_station_tb
python sim/run.py rn_dp_tb
```

## Tests

| Top | DUT | Style | Config |
|-----|-----|-------|--------|
| `bypass_tb` | `bypass_unit` | Directed expect | `sim/config/s4_dispatch/bypass_tb.json` |
| `selector_tb` | `selector_unit` (+ `rs_issue`) | Directed expect | `sim/config/s4_dispatch/selector_tb.json` |
| `reservation_station_tb` | `reservation_station` (+ wakeup/alloc) | Directed expect | `sim/config/s4_dispatch/reservation_station_tb.json` |
| `rn_dp_tb` | `rn_dp` | Directed | `sim/config/s4_dispatch/rn_dp_tb.json` |

| Path | Role |
|------|------|
| `tests/` | Directed `*_tb.sv` |
| `infra/` | `dispatch_monitor`, `issue_monitor` (scaffolds) |
| `../dpi/shims/s4_dispatch/` | `register_file_gm.sv` (legacy RF) |
| `../../model/s4_dispatch/` | C++ RF golden |

## Coverage (issue peers)

**bypass_tb** — idle, dual ready (p0), unready src, WB wake, same-pair RAW (rs1/rs2).

**selector_tb** — dual bypass issue, oldest bank vs bypass, bank+bypass mix, flush, full-bank stall, dual bypass when full, WB wakes bank entry.

**reservation_station_tb** — reset, bypass-accept marks dest unready, store unready pair, WB wakeup, free issued way, flush, selective path squash, `stall_dp` blocks store, fill 16 ways.

## Notes

- `pick` / `stall_dp` on the RS TB are **driven** as if from `selector_unit` (unit isolation).
- `tests/register_file_tb.sv` targets legacy `register_file` and is **not** registered in `.slang/project.f` / `sim/run.py` yet; current PRF DUT is `p_register_file`.
- RTL: `rtl/s4_dispatch/issue_core_struct.sv` and `core_mod/`.
