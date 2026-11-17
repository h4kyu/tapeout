"""Character IDs, row orientation, and blank fallbacks for the on-chip font."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def font_character_mapping(dut):
    glyphs = {}
    for character in range(64):
        rows = []
        dut.font_character.value = character
        for row in range(16):
            dut.font_row.value = row
            await Timer(1, unit="ns")
            pixels = dut.font_pixels.value
            assert pixels.is_resolvable
            value = int(pixels)
            if character == 0 or character >= 41 or row >= 12:
                assert value == 0, (character, row, value)
            rows.append(value)
        if 1 <= character <= 40:
            assert any(rows), f"Missing glyph for character ID {character}"
            glyphs[character] = tuple(rows[:12])

    assert len(set(glyphs.values())) == 40, "Supported glyphs must be distinct"
    # Known source glyphs pin down the digit/letter ID offsets and pixel order.
    assert glyphs[1] == (496, 2040, 1592, 3614, 3614, 3614,
                         3614, 3614, 2040, 496, 0, 0)  # 0
    assert glyphs[11] == (496, 2040, 1976, 3614, 3614, 4094,
                          4094, 3614, 3614, 3614, 0, 0)  # A
    assert glyphs[36] == (4094, 4094, 62, 248, 248, 496,
                          1984, 1984, 4094, 4094, 0, 0)  # Z

    # Suit IDs follow the core's C/D/H/S order and are horizontally symmetric.
    for suit in range(37, 41):
        assert all(f"{bits:012b}" == f"{bits:012b}"[::-1] for bits in glyphs[suit])
    assert glyphs[37][0] == 0b000011110000  # Club lobe
    assert glyphs[38][0] == 0b000001100000  # Diamond point
    assert glyphs[39][0] == 0b001110011100  # Heart lobes
    assert glyphs[40][0] == 0b000001100000  # Spade point
    assert glyphs[38][10:] == (0, 0)
    assert glyphs[39][10:] == (0, 0)
    assert glyphs[40][11] == 0b000111111000 # Spade stem base
