# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v debounce.v poker_inputs.v prng.v poker_dealer.v poker_evaluator.v poker_core.v vga.v
UNIT_TEST_SOURCES = debounce.v poker_inputs.v prng.v poker_dealer.v poker_evaluator.v poker_core.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(filter-out $(UNIT_TEST_SOURCES),$(PROJECT_SOURCES)))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Standalone unit tests use RTL in both RTL and gate-level simulations.
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(UNIT_TEST_SOURCES))

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# Native-only commands also work in ordinary Python without Cocotb installed.
# An empty goal list retains Cocotb's default `sim` target.
NATIVE_GOALS = native-build benchmark-vga test-vga-tools play-vga capture-vga
ifneq ($(strip $(MAKECMDGOALS)),)
ifeq ($(filter-out $(NATIVE_GOALS),$(MAKECMDGOALS)),)
SKIP_COCOTB = yes
endif
endif
ifneq ($(SKIP_COCOTB),yes)
include $(shell cocotb-config --makefiles)/Makefile.sim
endif

.PHONY: demo play play-lines play-vga capture-vga test-vga-tools
demo:
	$(MAKE) sim COCOTB_TEST_MODULES=sim.poker_demo COCOTB_TEST_FILTER= COCOTB_TESTCASE=

play:
	$(MAKE) sim COCOTB_TEST_MODULES=sim.poker_terminal COCOTB_TEST_FILTER= COCOTB_TESTCASE=

play-lines:
	POKER_LINE_MODE=1 $(MAKE) play

# VGA playback and capture use the native Verilator model without waveforms.
play-vga:
	python3 -m sim.native_vga

capture-vga:
	VGA_HEADLESS=1 $(MAKE) play-vga

test-vga-tools:
	python3 -m pytest -q sim/tests/test_vga_tools.py

.PHONY: native-build benchmark-vga test-native
native-build:
	python3 -m sim.build_native

benchmark-vga:
	VGA_BENCHMARK=1 python3 -m sim.native_vga

test-native: native-build
	python3 -m pytest -q sim/tests/test_native.py
	$(MAKE) sim COCOTB_TEST_MODULES=sim.tests.test_native_equivalence COCOTB_TEST_FILTER= COCOTB_TESTCASE= COCOTB_PLUSARGS="$(COCOTB_PLUSARGS) +NO_WAVES"
	@! grep '<failure' results.xml
	@mkdir -p output
	cp results.xml output/native-results.xml

.PHONY: test-sim
test-sim:
	$(MAKE) test-vga-tools
	$(MAKE) test-native
	$(MAKE) sim COCOTB_TEST_MODULES=sim.tests.test_harness COCOTB_TEST_FILTER= COCOTB_TESTCASE= COCOTB_PLUSARGS="$(COCOTB_PLUSARGS) +NO_WAVES"
	@! grep '<failure' results.xml
	cp results.xml output/harness-results.xml
