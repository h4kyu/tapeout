# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from test_debounce import test_debounce
from test_prng import test_prng
from test_inputs import test_player_inputs
from test_core import (
    basic_deal_draw_round,
    hold_switches_do_not_trigger_deal_or_draw,
    evaluator_categories_and_reference,
    rejection_holds_and_accounting,
    all_hold_masks_and_random_rounds,
    bankruptcy_overflow_and_reset,
)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 40 ns (25 MHz)
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # TODO: implement tests
