# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import ReadOnly, Timer


def advance(state):
    """Advance x^8 + x^6 + x^5 + x^4 + 1, shifting toward bit 7."""
    feedback = ((state >> 7) ^ (state >> 5) ^ (state >> 4) ^ (state >> 3)) & 1
    return ((state << 1) & 0xFF) | feedback


async def tick(dut):
    # Also leave the previous ReadOnly phase before driving the clock.
    await Timer(20, unit="ns")
    dut.clk.value = 1
    await Timer(20, unit="ns")
    dut.clk.value = 0
    await ReadOnly()


def check_output(dut, state, ready, context):
    actual_ready = int(dut.prng_ready.value)
    assert actual_ready == ready, (
        f"{context}: expected ready {ready}, got {actual_ready}"
    )
    actual = int(dut.rand_num.value)
    assert actual == (state & 0x3F), (
        f"{context}: state 0x{state:02x}: "
        f"expected output {state & 0x3F}, got {actual}"
    )


@cocotb.test()
async def test_prng(dut):
    """Check reset, seed loading, zero fallback, and complete LFSR sequences."""
    dut = dut.prng_unit
    dut.clk.value = 0
    dut.rst_n.value = 1
    dut.seed.value = 0

    # Include upper-bit seeds, a zero seed, and a repeated seed after reseeding.
    for seed in (0x01, 0x80, 0xFF, 0x00, 0x3F, 0x40, 0xA5, 0x01):
        dut._log.info("PRNG: testing seed 0x%02x", seed)
        await Timer(5, unit="ns")
        dut.seed.value = seed
        dut.rst_n.value = 0
        # No rising clock edge occurs: reset must act asynchronously.
        await Timer(1, unit="ns")
        await ReadOnly()
        check_output(dut, 0, ready=0, context=f"Seed 0x{seed:02x}, asynchronous reset")

        # Clocks during reset must neither load the seed nor assert ready.
        for cycle in range(1, 3):
            await tick(dut)
            check_output(
                dut, 0, ready=0,
                context=f"Seed 0x{seed:02x}, held in reset, cycle {cycle}",
            )

        await Timer(5, unit="ns")
        dut.rst_n.value = 1
        await Timer(1, unit="ns")
        await ReadOnly()
        check_output(
            dut, 0, ready=0,
            context=f"Seed 0x{seed:02x}, reset released before first clock",
        )

        # The first rising edge loads the seed without advancing it.
        state = seed or 1
        await tick(dut)
        check_output(
            dut, state, ready=1,
            context=f"Seed 0x{seed:02x}, first clock seed loading (zero maps to 1)",
        )

        # Seed changes after initialization must not affect the running sequence.
        await Timer(1, unit="ns")
        dut.seed.value = seed ^ 0xFF
        for cycle in range(1, 256):
            state = advance(state)
            await tick(dut)
            check_output(
                dut, state, ready=1,
                context=f"Seed 0x{seed:02x}, sequence after seed input change, cycle {cycle}",
            )

        # Continue beyond the period and reset from an actively running state.
        state = advance(state)
        await tick(dut)
        check_output(
            dut, state, ready=1,
            context=f"Seed 0x{seed:02x}, sequence beyond full period, cycle 256",
        )
