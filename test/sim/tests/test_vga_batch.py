"""Batched verification clocks must preserve the original driver's semantics."""

import cocotb

from sim.poker_sim import PokerSim


@cocotb.test()
async def batched_clock_matches_pixel_driver(dut):
    if int(dut.GATE_LEVEL.value):
        return

    async def play(batch):
        sim = PokerSim(dut, batch_clocks=batch)
        pins = []
        sim.observe_cycles(lambda value, reset: pins.append((value, reset)))
        try:
            snapshots = [await sim.reset(42)]
            await sim.press_deal_draw("bounce")
            snapshots.append(await sim.wait_for_state(2))
            snapshots.append(await sim.set_holds(1, 3))
            await sim.press_deal_draw("clean")
            snapshots.append(await sim.wait_for_state(5))
            assert sim.accepted_presses == 2
            # Reset a second time, with an already-open capture stream.
            snapshots.append(await sim.reset(53))
            await sim.press_deal_draw("long")
            snapshots.append(await sim.wait_for_state(2))
            assert sim.accepted_presses == 1
            return snapshots, pins, sim.cycles
        finally:
            sim.close()

    reference = await play(False)
    actual = await play(True)
    assert actual == reference, "Batched clocks changed gameplay or captured pixel order"
