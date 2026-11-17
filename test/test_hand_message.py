"""All hand names, centered geometry, state visibility, and white/yellow stages."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def hand_message_requests(dut):
    names = {
        1: "JACKS OR BETTER", 2: "TWO PAIR", 3: "THREE OF A KIND", 4: "STRAIGHT",
        5: "FLUSH", 6: "FULL HOUSE", 7: "FOUR OF A KIND", 8: "STRAIGHT FLUSH",
        9: "ROYAL FLUSH",
    }
    characters = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    async def pixel(x, y):
        dut.message_x.value = x
        dut.message_y.value = y
        await Timer(1, unit="ns")
        return (int(dut.message_active.value), int(dut.message_character.value),
                int(dut.message_glyph_x.value), int(dut.message_glyph_y.value))

    for state in (2, 4, 5):
        dut.message_state.value = state
        for category, name in names.items():
            # Intentionally disagree with the unused source to catch using the
            # stale result before drawing, or ignoring the latch after drawing.
            dut.message_live_category.value = category if state != 5 else 0
            dut.message_result_category.value = category if state == 5 else 0
            left = 320 - len(name) * 10
            for column, character in enumerate(name):
                assert await pixel(left + column * 20, 220) == (
                    1, characters.index(character), 0, 4)
                assert int(dut.message_yellow.value) == (state != 2)
            for x, y in ((left - 1, 213), (left + len(name) * 20, 213),
                         (left, 212), (left, 233)):
                assert (await pixel(x, y))[0] == 0

    # Check both axes of 20px -> 12px scaling over a complete character cell.
    dut.message_state.value = 2
    dut.message_live_category.value = 1
    for y in range(20):
        for x in range(20):
            assert await pixel(170 + x, 213 + y) == (1, characters.index('J'),
                                                   x * 12 // 20, y * 12 // 20)

    for state in (0, 1, 3, 6, 7):
        dut.message_state.value = state
        dut.message_live_category.value = 9
        dut.message_result_category.value = 9
        assert (await pixel(210, 213))[0] == 0
    for state in (2, 4, 5):
        dut.message_state.value = state
        for category in (0, 10, 11, 12, 13, 14, 15):
            dut.message_live_category.value = category
            dut.message_result_category.value = category
            assert (await pixel(320, 213))[0] == 0
