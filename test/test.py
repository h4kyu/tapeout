# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


async def tick(dut):
    await ClockCycles(dut.clk, 1)
    await Timer(1, unit="ns")


@cocotb.test()
async def test_counter(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    await Timer(1, unit="us")
    assert dut.uio_out.value == 0
    assert dut.uio_oe.value == 0x00

    dut.rst_n.value = 1
    await tick(dut)
    assert dut.uio_out.value == 1

    dut.uio_in.value = 0xA5
    dut.ui_in.value = 0b00000001
    await tick(dut)
    assert dut.uio_out.value == 0xA5

    dut.ui_in.value = 0b00000010
    await tick(dut)
    assert dut.uio_out.value == 0xA6
    assert dut.uio_oe.value == 0xFF

    dut.ui_in.value = 0
    await Timer(1, unit="ns")
    assert dut.uio_oe.value == 0x00

    dut.uio_in.value = 0xFE
    dut.ui_in.value = 0b00000001
    await tick(dut)
    assert dut.uio_out.value == 0xFE

    dut.ui_in.value = 0
    await tick(dut)
    assert dut.uio_out.value == 0xFF
    await tick(dut)
    assert dut.uio_out.value == 0x00

    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    assert dut.uio_out.value == 0
