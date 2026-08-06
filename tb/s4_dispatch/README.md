# S4 Dispatch — testbenches

Peers under `dispatch_core`:

```text
dispatch_core
  ├── reservation_station   bank + select (ready / pick / issue); helpers in rs.sv
  └── physical_register     physical RF
```

## Run

```powershell
python sim/run.py reservation_station_tb
python sim/run.py dispatch_core_tb
python sim/run.py rn_dp_tb
```

## Tests

| Top | DUT | Style | Config |
|-----|-----|-------|--------|
| `reservation_station_tb` | `reservation_station` | Directed expect | `sim/config/s4_dispatch/reservation_station_tb.json` |
| `dispatch_core_tb` | `dispatch_core` | Directed expect | `sim/config/s4_dispatch/dispatch_core_tb.json` |
| `rn_dp_tb` | `rn_dp` | Directed | `sim/config/s4_dispatch/rn_dp_tb.json` |

| Path | Role |
|------|------|
| `tests/` | Directed `*_tb.sv` |
| `infra/` | `dispatch_monitor`, `issue_monitor` (scaffolds) |
| `../dpi/shims/s4_dispatch/` | `register_file_gm.sv` (legacy RF) |
| `../../model/s4_dispatch/` | C++ RF golden |

## Coverage

**reservation_station_tb** — dual rename issue, RAW store then issue, path filter, flush.

**dispatch_core_tb** — dual bypass issue (no RS stub), same-pair RAW store then issue, path filter, flush.

## Notes

- Bank stays inside `reservation_station` (no bank ports). TBs peek `dut.bank_*` / `dut.u_rs.bank_*` when needed.
- `tests/register_file_tb.sv` targets legacy `register_file` and is **not** registered in `.slang/project.f` / `sim/run.py` yet; current PRF DUT is `physical_register`.
- RTL: `rtl/s4_dispatch/dispatch_core.sv`, `core_mod/reservation_station.sv`, `funct_pkg/rs.sv`.
