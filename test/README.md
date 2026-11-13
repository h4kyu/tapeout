# Sample testbench for a Tiny Tapeout project

The chip testbench uses [cocotb](https://docs.cocotb.org/en/stable/) to drive the DUT and check the outputs.
See below to get started or for more information, check the [website](https://tinytapeout.com/hdl/testing/).

## Layout and test suites

Chip functionality tests stay directly in `test/`: `test.py`, `test_core.py`,
`test_debounce.py`, `test_inputs.py`, and `test_prng.py`. The shared RTL testbench,
Makefile, dependencies, and this guide also stay at the root.

Auxiliary tooling lives in the `sim` Python package:

```text
sim/
  poker_sim.py          shared gameplay driver and Cocotb adapter
  poker_controls.py     backend-independent terminal/browser controls
  poker_terminal.py     interactive Cocotb terminal entrypoint
  poker_demo.py         scripted Cocotb demonstration
  native_sim.py         ctypes adapter for the native model
  build_native.py       incremental Verilator build
  native_vga.py         viewer, headless capture, and benchmark entrypoint
  vga_capture.py        independent Python reference decoder and PNG encoder
  vga_viewer.py         HTTP transport
  vga_viewer.html       browser UI
  native/               C++ model harness, decoder, and simulation-only wrapper
  tests/                tests of the drivers, controls, decoder, and transport
```

From `test/`, `make` runs chip functionality tests. `make test-sim` runs all
auxiliary checks: host-side viewer/decoder tests, native contracts and
Cocotb equivalence, terminal controls, the scripted demo, and batching checks.
CI runs both suites. `make test-native` and `make test-vga-tools` remain available
for narrower checks. Interactive commands (`make play`, `make play-lines`,
`make play-vga`), `make demo`, captures, and benchmarks keep the same names.

Modules use package imports, for example `from sim.poker_sim import PokerSim`.
Run Python entrypoints from `test/` with `python3 -m sim.native_vga` or
`python3 -m sim.build_native`. Generated files remain under `test/sim_build/`
and `test/output/`; moving the tooling does not move captures or build artifacts.

## Setting up

1. Edit [Makefile](Makefile) and modify `PROJECT_SOURCES` to point to your Verilog files.
2. Edit [tb.v](tb.v) and replace `tt_um_example` with your module name.

## How to run

To run the RTL simulation:

```sh
make -B
```

To run gatelevel simulation, first harden your project and copy `../runs/wokwi/results/final/verilog/gl/{your_module_name}.v` to `gate_level_netlist.v`.

Then run:

```sh
make -B GATES=yes
```

If you wish to save the waveform in VCD format instead of FST format, edit tb.v to use `$dumpfile("tb.vcd");` and then run:

```sh
make -B FST=
```

This will generate `tb.vcd` instead of `tb.fst`.

## PRNG reset and seed tests

`test_prng.py` is imported by `test.py` and runs with the normal RTL suite. It checks that asynchronous reset clears the PRNG output and `prng_ready` without a clock edge, and that both stay zero while reset is held. Releasing reset does not load the seed immediately: the first rising clock edge loads it and asserts `prng_ready`. The seed must be stable through that edge; a zero seed loads `8'h01` instead.

The test compares complete LFSR sequences against a Python reference for several seeds, checks that later seed-input changes are ignored, and verifies reset and reseeding. In gate-level runs, this standalone PRNG test still exercises the RTL instance in `tb.v`.

## Poker core tests

The game-logic tests run alongside the wrapper and debounce tests using the
pinned dependencies in `requirements.txt` and Icarus Verilog. From `test/`, run:

```sh
make
```

Standalone core and evaluator instances in `tb.v` are tested through the
decorated tests imported from `test_core.py` into `test.py`.
They test the controller, dealer, and evaluator with deterministic card candidates,
without requiring a PRNG or VGA implementation. Tests include a basic complete
round, hold switches changing independently of Deal/Draw, hand categories and
payouts, invalid and duplicate cards, all hold masks, balance limits, and reset.
The suite also compares 3,000 random hands with a Python reference evaluator.
Results for the combined suite are written to `results.xml` by the existing CI
test step. In gate-level simulation, these standalone units use RTL, just like
the standalone debounce unit.

## Player input adapter tests

`test_inputs.py` checks the standalone `poker_inputs` adapter with a five-cycle
debounce interval. It verifies two-stage hold synchronization, short press and
release rejection, exactly one pulse per sustained press, rearming after a stable
release, and asynchronous reset. The production default remains 500,000 cycles.
The adapter is connected to the project wrapper and poker core.

## Integrated project tests

`integrated_rounds` in `test.py` drives the wrapper's external inputs and reads
its internal game-state wires. It checks complete seeded rounds, all/none/mixed
holds, rejected short presses, held-button behavior, payouts, subsequent rounds,
and reset during dealing. RTL tests override the wrapper's `DEBOUNCE_CYCLES`
parameter to five; synthesis and gate-level simulation retain 500,000 cycles.
The internal-state test does not exercise a flattened gate-level netlist; the
gate-level wrapper test currently checks the zero-output VGA stub and
bidirectional outputs across reset.
Full gate-level gameplay coverage remains to be added.

The initial VGA integration uses a constant-zero RGB/sync stub, which does not
produce a valid VGA signal. With an active renderer, `uo_out` instead carries
the RGB and sync levels defined by `vga.v`. The temporary game-status byte has
been removed.
Cards, held flags, balance, category, payout, and state are named wires in
`project.v` for the upcoming renderer and ASCII simulation interface.
The simulator derives `can_deal` from state IDLE/RESULT and a balance of at least
five credits instead of reading an unused wrapper wire.

## Live VGA viewer and PNG capture

The VGA frontend observes the real `uo_out` RGB/sync pins on every clock driven
by `PokerSim`, including clocks consumed by button presses and resets. It does
not draw cards from game state or read the renderer's internal pixel counters.
The terminal remains available through `make play` and `make play-lines`.

Run these commands **inside the dev container**, from `test/`, with the existing
`requirements.txt` dependencies installed. No additional Python packages are
needed for VGA tools.
These frontends require RTL game-state visibility and do not support `GATES=yes`.

```sh
make play-vga
```

Open `http://localhost:8765` in your host browser. In VS Code, forward port 8765
using the **Ports** tab if it is not forwarded automatically; the dev-container
configuration includes this port for future sessions. Use the forwarded URL if
VS Code assigns a different local port. A bare `docker exec` session does not
automatically expose a container's localhost port to the host.

The viewer provides the actual 640×480 frame alongside the existing terminal
diagnostics. Space deals/draws, 1–5 toggle holds, R resets to seed 42, B cycles
button profiles, and Q stops the simulation/server. Controls are also available
as buttons. The initial seed is configurable with `VGA_SEED` (default 42).
Only the simulation task drives clocks and handles queued input; HTTP threads
never access RTL objects. The page polls while simulation continues, so it stays
responsive even before a complete frame arrives.

Capture a deterministic screenshot without a window:

```sh
make capture-vga
VGA_SEED=42 VGA_COMMANDS='deal;hold 1 3;draw' VGA_OUTPUT=output/result.png make capture-vga
```

The default output is `test/output/vga.png`, with a `.json` sidecar containing
the game snapshot, frame number, cycle count, and sync-error count. Commands are
the same as the terminal command interface and execute before capture. Generated
files are ignored by Git. View the PNG directly, or use the live page's PNG link.

The capture contract is active-low 640×480 VGA: 800 clocks per line, 525 lines per
frame, horizontal sync at 656–751 and vertical sync on lines 490–491. Two-bit
RGB channel values map to 0, 85, 170 and 255. Partial frames are discarded until
sync is acquired and a complete image is received. Wrong sync widths/periods
and colored blanking are reported rather than shifted into an apparently valid
picture. Constant-zero sync from the committed shell displays
“Waiting for VGA sync”; headless mode times out with an explanatory error.

At 25 MHz each frame takes 420,000 simulated clocks. The viewer uses
**Verilator**, compiled as an optimized single-threaded C++ model without tracing.
Both model evaluation and external-pin VGA decoding stay in C++; Python receives
only completed RGBA frames when the browser requests them. The browser presents
at up to 30 FPS with one frame request outstanding and polls diagnostics at 5 Hz.
It shows backend, simulated clocks/second, generated FPS, and displayed FPS
separately. PNG encoding happens only for captures/downloads. HTTP uses persistent
connections to avoid truncated large responses on forwarded ports.

```sh
make play-vga                             # Verilator, uncapped
make capture-vga                          # Verilator PNG + JSON
VGA_DEBOUNCE_CYCLES=500000 make play-vga    # production debounce
make benchmark-vga                        # execution and capture throughput
make test-sim                             # all auxiliary simulation/harness tests
make test-native                          # native contracts + Cocotb equivalence
make test-vga-tools                       # Python capture/transport tests
make                                      # existing Icarus RTL suite
```

The dev container includes Verilator, g++, and make; the native interface uses
standard-library `ctypes` and needs no Python development headers or binding
package. Missing tools produce an error rather than silently choosing Icarus.
`sim/build_native.py` caches the library under ignored `sim_build/native/`, keyed by
all RTL, wrapper, C++ sources, build script, compiler versions, flags, and debounce
configuration. Restart after editing Verilog; the next run rebuilds automatically.
A simulation-only wrapper exposes read-only game diagnostics. The production RTL
and ports are unchanged. All gameplay still enters through reset and physical
input pins. Each complete cycle evaluates low, samples settled outputs and the
accepted-button pulse, then evaluates high, advancing logical time by 40 ns.

The shared `PokerSim(dut)` interface remains compatible with Cocotb callers.
`PokerSim.native(debounce_cycles=5)` provides the same async reset, holds, button
profiles, waits, snapshots, and counters without importing Cocotb. Call `close()`
when finished. Backend-independent terminal controls live in `sim/poker_controls.py`;
`sim/poker_terminal.py` remains the Cocotb entrypoint and re-exports those controls.
Only one task owns each model. HTTP threads enqueue controls and read immutable
snapshots; native calls release the GIL. Controls are processed between batches
of at most 16,384 clocks. The native decoder uses two framebuffers, retaining only
the newest complete frame while simulating every clock. Cycle observers enable
bounded pin traces for debugging and equivalence tests; leave them off for speed.

Simulation runs **uncapped**. A seed and key sequence alone do not reproduce live
hands because the PRNG keeps running: deterministic replay requires the same
inputs at the same simulation cycles. Headless scripted captures use an exact
cycle schedule. The five-cycle debounce default matches the Cocotb testbench;
production remains 500,000 cycles. Verilator is two-state: retain Icarus for
X/Z-sensitive checks.

`VGA_MAX_CYCLES` bounds headless acquisition (default 1,260,000 clocks), and
`VGA_PORT` changes the live port (default 8765). If the port is occupied, stop the
previous viewer with Q, or use another port, for example
`VGA_PORT=8766 make play-vga`. Ctrl-Z suspends a process and keeps its port open;
resume it with `fg` and then stop it. The viewer never kills other processes.
Native shutdown releases the model and closes the server. The viewer does not
generate waveforms. Icarus/Cocotb remains the verification backend, including
X/Z-sensitive checks and independent pixel comparisons against Verilator. Its
batched test driver runs clocks in the HDL testbench and transfers a bounded
scratch pin file to the Python reference decoder. Run only one batched Cocotb
test process in a directory at a time because that scratch file is shared.

Measured in the current development container (Verilator 5.020, g++ 13.3): initial
native build about 3.5 seconds, first completed frame about 44 ms after reset,
execution about 21.9 million clocks/second, and capture about 19.9 million
clocks/second (47 generated FPS). The forwarded browser sustained approximately
29–30 displayed FPS after warm-up, with responsive deal/hold/draw controls and no
sync errors. These measurements depend on the machine and renderer complexity.
The acceptance floor is 12.6 million clocks/second with decoding (30 generated
FPS). `benchmark-vga` measures after warm-up, writes `output/vga-benchmark.json`,
and fails if capture throughput misses that floor; browser FPS is measured
separately in the live page.

Native correctness tests compare snapshots, accepted pulses, cycle counts,
directed output-pin traces, and complete RGB frames against Cocotb. Synthetic
signals exercise palette/alignment, partial frames, reset, inactive sync,
malformed sync, and blanking in both decoders. CI installs Verilator and runs
these checks alongside the existing RTL and viewer tests.

## ASCII simulation demo

With the dependencies in `requirements.txt` installed and Icarus Verilog on
your PATH, run from `test/`:

```sh
make demo
```

This runs the actual top-level RTL and prints cards, held indicators, balance,
state, hand category, and payout to stdout. The fixed seed is 42. The script
plays three rounds: hold cards 1 and 3, hold all five, and replace all five.
It repeats the same command schedule and asserts identical results. Assertions
also check holds, valid unique cards, discard rejection, and accounting against
the Python reference evaluator. The demo is included in `make test-sim`.

`sim/poker_sim.py` provides `PokerSim.reset(seed)`, `set_holds(*positions)` (positions
1 through 5), `press_deal_draw()`, `wait_for_state(state)`, `advance(cycles)`, and
`snapshot()`. It drives only external inputs; snapshots read internal RTL wires.
Each printed command includes its simulation cycle for replay. A seed alone
does not fix a hand: the free-running PRNG also depends on command timing.

The testbench uses a five-cycle debounce interval for speed; production RTL
keeps its 20 ms default. The driver reads the configured interval rather than
bypassing debounce. Time advances at 25 MHz during driver operations and pauses
between them. This is a scripted RTL simulation, with no VGA or interactive
terminal commands, and requires internal signals unavailable in a flattened
gate-level netlist. For interactive controls, use the terminal below.

## Interactive terminal

From `test/` with the test environment activated:

```sh
make play
```

The terminal now opens a persistent game screen (use a terminal at least 72
columns wide). Balance, wager, cards, held indicators, result, and payout stay
visible. No Enter key is required:

- **Space** presses the Deal/Draw button.
- **1–5** toggle the corresponding hold switches.
- **B** cycles button profiles: clean, bounce, short, long.
- **R** resets to 100 credits with seed 42.
- **Q** quits; Ctrl-C also restores the terminal before exiting.

The button profiles drive waveforms on the real `ui_in[5]` input, through the
synchronizer, debounce module, and pulse detector. Clean uses a stable press;
bounce adds one-cycle chatter on both press and release; short lasts less than
the debounce threshold and should be rejected; long stays high for an extra
512 cycles and should still trigger only once. The screen shows the number of
accepted input pulses and the outcome of the last action. These are deterministic
simulation stimuli, not a measurement of keyboard contact bounce or wall-clock
key duration. Production timing remains 20 ms; the testbench uses five cycles.

Simulation time pauses between keys. The same seed and key sequence reproduce
the same hands. Rendering and changing profiles do not advance RTL time.
The screen uses `/dev/tty` directly so simulator-wrapped stdout does not cause
a fallback to line mode. Ctrl-C is read as an exit key rather than sending a
signal to the simulator and its parent make processes. The screen restores the
normal terminal on exit. To explicitly use the original line-command interface
for scripts, run `make play-lines`: `deal`,
`hold 1 3`, `hold none`, `draw`, `reset 42`, `show`, `help`, and `quit`.

The terminal runs only when selected with `make play`, so normal tests never
wait for keyboard input. `sim/tests/test_terminal.py` checks command handling, screen
controls, short-press rejection, one action for a sustained press, bounce
filtering, and release rearming through the integrated RTL.

## How to view the waveform file

Using GTKWave

```sh
gtkwave tb.fst tb.gtkw
```

Using Surfer

```sh
surfer tb.fst
```
