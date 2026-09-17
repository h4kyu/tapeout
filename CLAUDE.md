# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Tiny Tapeout Verilog project — currently the unmodified upstream template. The design is hardened into GDS by GitHub Actions (LibreLane) targeting the **gf180mcuD** PDK; there is no local hardening flow checked in.

## Commands

All simulation commands run from `test/`:

```sh
make -B                 # RTL simulation (icarus + cocotb)
make -B GATES=yes       # gate-level sim; requires test/gate_level_netlist.v (see below)
make -B FST=            # dump VCD instead of FST (also edit $dumpfile in tb.v)
make clean              # sim_build/ and results are stale-prone; CI always runs clean first
```

`make` exits 0 even when a test fails — verify by checking `test/results.xml` for `<failure>` (this is exactly what `.github/workflows/test.yaml` does with `! grep failure results.xml`).

Running a single test: `COCOTB_TEST_MODULES` in `test/Makefile` selects the Python module(s); within a module, filter with cocotb's env var, e.g. `make -B COCOTB_TESTCASE=test_project`.

Viewing waves: `gtkwave test/tb.fst test/tb.gtkw` or `surfer test/tb.fst`.

Dependencies: `iverilog` plus `pip install -r test/requirements.txt` (cocotb 2.0.x — note the 2.x API, e.g. `Clock(..., unit="us")`, not `units=`). The `.devcontainer` image provides iverilog, verilator, verible, LibreLane and the PDK.

Gate-level sim needs `test/gate_level_netlist.v`, copied from a hardened run (`runs/wokwi/results/final/verilog/gl/<top_module>.v`) or pulled in by the GDS workflow. It compiles against `$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/`.

## Architecture

The whole design is one module with a fixed port list dictated by the Tiny Tapeout harness — 8 dedicated inputs (`ui_in`), 8 dedicated outputs (`uo_out`), 8 bidirectional pins (`uio_in`/`uio_out`/`uio_oe`, oe active-high: 1 = drive), plus `ena`, `clk`, `rst_n` (active-low reset). Every output must be driven; tie unused ones to 0 and sink unused inputs into a `wire _unused = &{...}` so the linter stays quiet (`RUN_LINTER` is on and lint failures fail the GDS build).

Four things must be kept in sync whenever the top module is renamed or source files are added:

1. `src/` — the Verilog itself; top module name must start with `tt_um_`.
2. `info.yaml` — `top_module` and `source_files` (each file listed separately, paths relative to `src/`). Also `tiles`, `clock_hz`, and the `pinout` section, which feeds the datasheet and website.
3. `test/Makefile` — `PROJECT_SOURCES` mirrors `source_files`.
4. `test/tb.v` — instantiates the top module by name.

`docs/info.md` is the project datasheet; the `docs` workflow renders it.

`src/config.json` is the LibreLane config. Only `PL_TARGET_DENSITY_PCT`, `CLOCK_PERIOD`, and the two hold-slack margins are meant to be touched (raise density if global placement fails with GPL-0302; raise `CLOCK_PERIOD` on setup violations, margins on hold violations). Everything below the "DO NOT CHANGE" banner is harness-critical.

`tb.v` is a thin wrapper: it instantiates the DUT, dumps waves, and adds `VPWR`/`VGND` under `` `ifdef GL_TEST `` so the same testbench serves RTL and gate-level runs. Test logic lives in `test/test.py`.

## CI

- `test.yaml` — RTL cocotb tests on every push.
- `gds.yaml` — hardens with LibreLane, then runs precheck, gate-level tests, and publishes the GDS viewer to GitHub Pages.
- `docs.yaml` — builds the datasheet.
- `fpga.yaml` — ICE40UP5K bitstream; disabled by default (`branches: none`), manual dispatch only.

All use `TinyTapeout/tt-gds-action@ttgf26a`; that tag pins the shuttle.
