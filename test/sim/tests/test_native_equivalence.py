"""Native and batched clock drivers must match the reference Cocotb driver."""
import cocotb
from sim.poker_sim import PokerSim
from sim.vga_capture import VGACapture, FRAME_CLOCKS
from sim.native_vga import rgb


@cocotb.test()
async def native_matches_cocotb(dut):
    reference = PokerSim(dut, batch_clocks=True)
    native = PokerSim.native()
    observed = [[], []]
    for sim, trace in zip((reference, native), observed):
        sim.observe_cycles(lambda pins, reset, trace=trace: trace.append((pins, reset)))

    async def both(method, *args):
        results = []
        for sim in (reference, native):
            result = await getattr(sim, method)(*args)
            results.append((result, sim.snapshot(), sim.cycles, sim.accepted_presses))
        assert results[0] == results[1], (method, args, results)
        assert observed[0] == observed[1], (method, args, 'pin trace mismatch')
        for trace in observed:
            trace.clear()

    try:
        await both('reset', 42)
        await both('press_deal_draw', 'short')
        assert native.accepted_presses == 0
        await both('press_deal_draw', 'bounce')
        await both('wait_for_state', 2)
        await both('set_holds', 1, 3)
        await both('press_deal_draw', 'clean')
        await both('wait_for_state', 5)
        await both('press_deal_draw', 'long')
        await both('wait_for_state', 2)
        await both('set_holds')
        await both('press_deal_draw')
        await both('wait_for_state', 5)
        await both('reset', 53)
        # No Python pin transfer for native frame capture. Cocotb reference
        # decodes every external sample independently into an RGB image.
        native.cycle_observers.clear()
        reference.cycle_observers.clear()
        capture = VGACapture()
        reference.observe_cycles(capture.sample)
        for _ in range((2 * FRAME_CLOCKS) // 16000 + 1):
            await reference.advance(16000)
            await native.advance(16000)
            if capture.latest:
                break
        metrics = native.driver.metrics()
        if capture.latest is None:
            # Tooling can be committed before the active VGA implementation.
            assert capture.previous_h == capture.previous_v == 0, capture.status
            assert not metrics.ready and metrics.frames == 0
        else:
            number, rgba = native.driver.latest_rgba()
            assert number == capture.latest.number
            assert rgb(rgba) == capture.latest.rgb
        assert metrics.errors == capture.errors == 0
        # Reset while locked/part way into another frame: discard partial image.
        await reference.reset(42)
        await native.reset(42)
        assert capture.latest is None and not native.driver.metrics().ready
    finally:
        reference.close(); native.close()


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
