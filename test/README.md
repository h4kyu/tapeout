# Sample testbench for a Tiny Tapeout project

This is a sample testbench for a Tiny Tapeout project. It uses [cocotb](https://docs.cocotb.org/en/stable/) to drive the DUT and check the outputs.
See below to get started or for more information, check the [website](https://tinytapeout.com/hdl/testing/).

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
gate-level wrapper test currently checks reset status and bidirectional outputs.
Full gate-level gameplay coverage remains to be added.

Until VGA is integrated, `uo_out` carries temporary status:
`{can_deal, state[2:0], result_category[3:0]}`. These pins are not VGA signals.
Cards, held flags, balance, category, payout, and state are named wires in
`project.v` for the upcoming renderer and ASCII simulation interface.

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
the Python reference evaluator. The demo is included in the normal RTL suite.

`poker_sim.py` provides `PokerSim.reset(seed)`, `set_holds(*positions)` (positions
1 through 5), `press_deal_draw()`, `wait_for_state(state)`, `advance(cycles)`, and
`snapshot()`. It drives only external inputs; snapshots read internal RTL wires.
Each printed command includes its simulation cycle for replay. A seed alone
does not fix a hand: the free-running PRNG also depends on command timing.

The testbench uses a five-cycle debounce interval for speed; production RTL
keeps its 20 ms default. The driver reads the configured interval rather than
bypassing debounce. Time advances at 25 MHz during driver operations and pauses
between them. This is a scripted RTL simulation, with no VGA or interactive
terminal commands yet, and requires internal signals unavailable in a flattened
gate-level netlist. Interactive controls are the next step.

## How to view the waveform file

Using GTKWave

```sh
gtkwave tb.fst tb.gtkw
```

Using Surfer

```sh
surfer tb.fst
```
