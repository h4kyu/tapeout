"""HOLD requests use centered glyphs and preserve green inter-letter spacing."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def hold_label_geometry(dut):
    characters = (18, 25, 22, 14)  # H O L D
    dut.hold_selected.value = 0b10101
    for y in range(245, 259):
        dut.hold_y.value = y
        for x in range(640):
            dut.hold_x.value = x
            await Timer(1, unit="ns")
            expected = None
            for card in (0, 2, 4):
                for column, character in enumerate(characters):
                    left = 128 * card + 32 + 16 * column
                    if 246 <= y < 258 and left <= x < left + 12:
                        expected = (character, x - left, y - 246)
            assert int(dut.hold_text_active.value) == (expected is not None), (x, y)
            if expected:
                assert (int(dut.hold_character.value), int(dut.hold_glyph_x.value),
                        int(dut.hold_glyph_y.value)) == expected

    # Check each selected bit independently across all possible hold masks.
    dut.hold_y.value = 246
    for mask in range(32):
        dut.hold_selected.value = mask
        for card in range(5):
            dut.hold_x.value = 32 + 128 * card
            await Timer(1, unit="ns")
            assert int(dut.hold_text_active.value) == bool(mask & (1 << card))
