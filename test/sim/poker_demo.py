"""Repeatable stdout demonstration of the actual top-level poker RTL."""

import cocotb

from sim.poker_sim import PokerSim
from test_core import PAYOUTS, reference


@cocotb.test()
async def scripted_ascii_demo(dut):
    if int(dut.GATE_LEVEL.value):
        dut._log.info("ASCII demo requires RTL state visibility")
        return
    sim = PokerSim(dut)
    print("\nASCII RTL DEMO | seed=42 | C=clubs D=diamonds H=hearts S=spades", flush=True)

    def show(command, snapshot, display):
        if display:
            print(f"\n> {command}  [cycle {sim.cycles}]\n{snapshot.ascii()}", flush=True)

    async def play(display=True):
        snapshots = [await sim.reset(seed=42)]
        show("reset 42", snapshots[-1], display)
        for positions in ((1, 3), (1, 2, 3, 4, 5), ()):
            before = sim.snapshot().balance
            await sim.set_holds()
            await sim.press_deal_draw()
            initial = await sim.wait_for_state(2)
            assert initial.balance == before - 5
            assert len(set(initial.cards)) == 5
            show("deal", initial, display)
            held = await sim.set_holds(*positions)
            assert held.holds == sum(1 << (i - 1) for i in positions)
            show("hold " + (" ".join(map(str, positions)) or "none"), held, display)
            await sim.press_deal_draw()
            result = await sim.wait_for_state(5)
            assert len(set(result.cards)) == 5
            assert all(2 <= (c & 15) <= 14 for c in result.cards)
            for i, card in enumerate(result.cards, 1):
                if i in positions:
                    assert card == initial.cards[i - 1]
                else:
                    assert card not in initial.cards
            assert result.category == reference(result.cards)
            assert result.payout == PAYOUTS[result.category]
            assert result.balance == before - 5 + result.payout
            show("draw", result, display)
            snapshots.extend((initial, held, result))
        return snapshots

    first = await play()
    # Repeat the exact input schedule to check replay through the shared driver.
    replay = await play(display=False)
    assert replay == first, "Seed and command timing must reproduce every snapshot"
    print("\nPASS: three rounds and identical seeded replay verified.\n", flush=True)
