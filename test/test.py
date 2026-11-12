# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

from test_debounce import test_debounce
from test_prng import test_prng
from test_inputs import test_player_inputs
from poker_demo import scripted_ascii_demo
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
    """Reset status is also checked against the synthesized top level in GL runs."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 42
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    await Timer(1, unit="ns")
    assert int(dut.uo_out.value) == 0x80
    assert int(dut.uio_out.value) == 0
    assert int(dut.uio_oe.value) == 0
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    await Timer(1, unit="ns")
    assert int(dut.uo_out.value) == 0x80


@cocotb.test()
async def integrated_rounds(dut):
    """Drive only external controls; inspect RTL game state before VGA exists."""
    if int(dut.GATE_LEVEL.value):
        dut._log.info("RTL state inspection is unavailable in flattened gate-level netlists")
        return

    from test_core import hand, reference, PAYOUTS

    game = dut.user_project

    async def tick(count=1):
        for _ in range(count):
            dut.clk.value = 0
            await Timer(20, unit="ns")
            dut.clk.value = 1
            await Timer(20, unit="ns")

    async def reset():
        dut.clk.value = 0
        dut.ena.value = 1
        dut.ui_in.value = 0
        dut.uio_in.value = 42
        dut.rst_n.value = 0
        await Timer(1, unit="ns")
        assert int(game.balance.value) == 100
        assert int(game.cards.value) == 0
        assert int(game.state.value) == 0
        await tick(3)
        dut.rst_n.value = 1
        await tick(3)

    async def wait_state(expected):
        for _ in range(300):
            if int(game.state.value) == expected:
                return
            await tick()
        assert False, f"Timed out waiting for state {expected}"

    async def press(holds):
        dut.ui_in.value = holds | 32
        await tick(10)

    async def release(holds):
        dut.ui_in.value = holds
        await tick(10)

    first_hand = None
    for mask in (0, 31, 5):
        await reset()
        # Switches alone cannot deal, and a short button bounce is ignored.
        dut.ui_in.value = 31
        await tick(4)
        assert int(game.state.value) == 0
        dut.ui_in.value = 32
        await tick(2)
        await release(0)
        assert int(game.state.value) == 0
        await press(0)
        await wait_state(2)
        initial = hand(game)
        assert len(set(initial)) == 5
        assert all(2 <= (c & 15) <= 14 for c in initial)
        assert int(game.balance.value) == 95
        if first_hand is None:
            first_hand = initial
        else:
            assert initial == first_hand, "Identical reset seed and timing must replay"
        # Holding the button through deal completion cannot initiate a draw.
        await tick(300)
        assert int(game.state.value) == 2
        await release(mask)
        assert int(game.held_cards.value) == mask
        assert int(game.state.value) == 2
        await press(mask)
        await wait_state(5)
        final = hand(game)
        assert len(set(final)) == 5
        assert all(2 <= (c & 15) <= 14 for c in final)
        for i in range(5):
            if mask & (1 << i):
                assert final[i] == initial[i]
            else:
                assert final[i] not in initial, "Discarded cards cannot be redealt"
        category = reference(final)
        assert int(game.result_category.value) == category
        assert int(game.result_payout.value) == PAYOUTS[category]
        assert int(game.balance.value) == 95 + PAYOUTS[category]
        await tick(300)
        assert int(game.state.value) == 5
        assert int(game.balance.value) == 95 + PAYOUTS[category]
        await release(0)
        await press(0)
        await wait_state(2)
        assert int(game.balance.value) == 90 + PAYOUTS[category]
        assert int(game.result_payout.value) == 0

    # Reset an in-progress deal through the actual reset pin.
    await reset()
    dut.ui_in.value = 32
    await wait_state(1)
    await reset()
