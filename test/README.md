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
The adapter is not connected to the project wrapper yet.

## How to view the waveform file

Using GTKWave

```sh
gtkwave tb.fst tb.gtkw
```

Using Surfer

```sh
surfer tb.fst
```
