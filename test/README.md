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

## Poker core tests

The standalone game-logic suite uses the same pinned dependencies in
`requirements.txt` and Icarus Verilog. From `test/`, run:

```sh
make -f Makefile.core
```

It tests the controller, dealer, and evaluator with deterministic card candidates,
without requiring a PRNG or VGA implementation. Tests include a basic complete
round, hold switches changing independently of Deal/Draw, hand categories and
payouts, invalid and duplicate cards, all hold masks, balance limits, and reset.
The suite also compares 3,000 random hands with a Python reference evaluator.
Results are written to `results_core.xml`; CI runs both this suite and the
existing wrapper/debounce suite.

## How to view the waveform file

Using GTKWave

```sh
gtkwave tb.fst tb.gtkw
```

Using Surfer

```sh
surfer tb.fst
```
