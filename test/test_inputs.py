"""Check player input conditioning before connecting it to the game core."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_player_inputs(dut):
    async def tick(button=None, holds=None):
        dut.inputs_clk.value = 0
        if button is not None:
            dut.inputs_button.value = button
        if holds is not None:
            dut.inputs_holds.value = holds
        await Timer(20, unit="ns")
        dut.inputs_clk.value = 1
        await Timer(20, unit="ns")
        return int(dut.inputs_pulse.value)

    async def run(count, button=None):
        return [await tick(button=button) for _ in range(count)]

    dut.inputs_rst_n.value = 0
    await tick(button=0, holds=0)
    assert int(dut.inputs_hold_mask.value) == 0
    assert int(dut.inputs_pulse.value) == 0
    dut.inputs_rst_n.value = 1

    # Holds cross two registers and never generate a game action.
    for mask in (1, 21, 31, 0):
        previous = int(dut.inputs_hold_mask.value)
        assert await tick(holds=mask) == 0
        assert int(dut.inputs_hold_mask.value) == previous
        assert await tick() == 0
        assert int(dut.inputs_hold_mask.value) == mask

    assert sum(await run(2, button=1)) == 0
    assert sum(await run(10, button=0)) == 0
    pulses = await run(20, button=1)
    assert sum(pulses) == 1, "A long press must produce exactly one pulse"
    assert pulses[6] == 1, "Pulse follows synchronization and five stable samples"

    # Release bounce cannot rearm the accepted press.
    assert sum(await run(2, button=0)) == 0
    assert sum(await run(15, button=1)) == 0
    assert sum(await run(10, button=0)) == 0
    assert sum(await run(20, button=1)) == 1

    # Reset clears both synchronized holds and an active pulse asynchronously.
    await run(10, button=0)
    for _ in range(10):
        if await tick(button=1, holds=31):
            break
    else:
        assert False, "Stable press did not produce a pulse before reset"
    dut.inputs_rst_n.value = 0
    await Timer(1, unit="ns")
    assert int(dut.inputs_pulse.value) == 0
    assert int(dut.inputs_hold_mask.value) == 0
    await tick(button=0, holds=0)
    dut.inputs_rst_n.value = 1
    assert sum(await run(10)) == 0
