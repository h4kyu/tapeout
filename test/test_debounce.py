# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer


@cocotb.test()
async def test_debounce(dut):
    """Test a standalone debounce instance using its input and output ports."""
    dut = dut.debounce_unit
    cycles = int(dut.DEBOUNCE_CYCLES.value)
    button_out = dut.button_out

    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    dut.button_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    await ReadOnly()
    assert int(button_out.value) == 0, "Button should start released"

    # A short press should be ignored.
    dut._log.info("Debounce: ignore a short press")
    await FallingEdge(dut.clk)
    dut.button_in.value = 1
    await ClockCycles(dut.clk, cycles // 2)
    await ReadOnly()
    assert int(button_out.value) == 0
    await FallingEdge(dut.clk)
    dut.button_in.value = 0
    await ClockCycles(dut.clk, cycles + 3)
    await ReadOnly()
    assert int(button_out.value) == 0, "Short press must not become a press"

    # A stable press is accepted after two sync cycles plus the debounce time.
    dut._log.info("Debounce: accept a stable press")
    await FallingEdge(dut.clk)
    dut.button_in.value = 1
    await ClockCycles(dut.clk, cycles + 1)
    await ReadOnly()
    assert int(button_out.value) == 0, "Press accepted too early"
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(button_out.value) == 1, "Stable press was not accepted"

    # Holding the button should keep the debounced level high.
    await ClockCycles(dut.clk, 10)
    await ReadOnly()
    assert int(button_out.value) == 1

    # A short release should be ignored, just like a short press.
    dut._log.info("Debounce: ignore a short release")
    await FallingEdge(dut.clk)
    dut.button_in.value = 0
    await ClockCycles(dut.clk, cycles // 2)
    await ReadOnly()
    assert int(button_out.value) == 1
    await FallingEdge(dut.clk)
    dut.button_in.value = 1
    await ClockCycles(dut.clk, cycles + 3)
    await ReadOnly()
    assert int(button_out.value) == 1, "Short release must not release the button"

    dut._log.info("Debounce: accept a stable release")
    await FallingEdge(dut.clk)
    dut.button_in.value = 0
    await ClockCycles(dut.clk, cycles + 1)
    await ReadOnly()
    assert int(button_out.value) == 1, "Release accepted too early"
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(button_out.value) == 0, "Stable release was not accepted"

    # Reset should clear an accepted press without waiting for a clock edge.
    dut._log.info("Debounce: reset while pressed")
    await FallingEdge(dut.clk)
    dut.button_in.value = 1
    await ClockCycles(dut.clk, cycles + 2)
    await ReadOnly()
    assert int(button_out.value) == 1
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    await ReadOnly()
    assert int(button_out.value) == 0, "Reset must clear the button immediately"

    # Leave the DUT released and out of reset for subsequent checks.
    await FallingEdge(dut.clk)
    dut.button_in.value = 0
    await ClockCycles(dut.clk, 2)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    clock.stop()
