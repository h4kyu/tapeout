"""Footer decimal conversion, full balance range, atomic updates, and glyphs."""

import random
import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def credits_bet_readout(dut):
    async def tick(count=1):
        for _ in range(count):
            dut.status_clk.value = 0
            await Timer(20, unit="ns")
            dut.status_clk.value = 1
            await Timer(20, unit="ns")

    async def pixel(x, y):
        dut.status_x.value = x
        dut.status_y.value = y
        await Timer(1, unit="ns")
        return (int(dut.status_text_active.value), int(dut.status_character.value),
                int(dut.status_glyph_x.value), int(dut.status_glyph_y.value))

    dut.status_state.value = 0
    dut.status_payout.value = 0
    dut.status_clk.value = 0
    dut.status_rst_n.value = 0
    dut.status_balance.value = 100
    dut.status_x.value = 0
    dut.status_y.value = 0
    await tick(2)
    assert int(dut.status_unit.displayed_digits.value) == 0x00100
    dut.status_rst_n.value = 1

    rng = random.Random(42)
    balances = [0, 1, 4, 5, 9, 10, 99, 100, 999, 1000, 9999, 10000,
                65535, 65534, 32768, 4095, 45] + [rng.randrange(65536) for _ in range(128)]
    for balance in balances:
        dut.status_balance.value = balance
        await tick(36)
        assert int(dut.status_unit.displayed_digits.value) == int(f"{balance:05d}", 16)
        digits = f"{balance:05d}"
        for column in range(5):
            assert await pixel(555 + 12 * column, 446) == (1, int(digits[column]) + 1, 0, 0)
        label_left = 459
        for column, character in enumerate((13, 28, 15, 14, 19, 30, 29)):
            assert (await pixel(label_left + 12 * column, 446))[:2] == (1, character)

    # Conversion must never expose partially shifted BCD, even if balance
    # changes while a previous conversion is still running.
    dut.status_balance.value = 100
    await tick(36)
    dut.status_balance.value = 1000
    await tick(5)
    assert int(dut.status_unit.displayed_digits.value) == 0x00100
    dut.status_balance.value = 65535
    for _ in range(36):
        await tick()
        assert int(dut.status_unit.displayed_digits.value) in (0x00100, 0x01000, 0x65535)
    assert int(dut.status_unit.displayed_digits.value) == 0x65535

    # BET 5 is fixed and does not depend on current credits.
    for column, character in enumerate((12, 15, 30, 0, 6)):
        assert (await pixel(25 + 12 * column, 446))[:2] == (1, character)
    for gy in range(12):
        for gx in range(12):
            assert await pixel(25 + gx, 446 + gy) == (1, 12, gx, gy)
    for x, y in ((24, 446), (85, 446), (25, 445), (25, 458), (615, 446)):
        assert (await pixel(x, y))[0] == 0

    dut.status_balance.value = 7
    await tick(3)
    dut.status_rst_n.value = 0
    await Timer(1, unit="ns")
    assert int(dut.status_unit.displayed_digits.value) == 0x00100
