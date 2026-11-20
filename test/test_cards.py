"""Card geometry and centered rank and suit glyphs."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def card_faces_and_indices(dut):
    async def sample(x, y):
        dut.card_x.value = x
        dut.card_y.value = y
        await Timer(1, unit="ns")
        return tuple(int(signal.value) for signal in (
            dut.card_active, dut.card_text_active, dut.card_character,
            dut.card_glyph_x, dut.card_glyph_y, dut.card_red))

    dut.card_values.value = 0
    for slot in range(5):
        left = 128 * slot
        for x, y, inside in ((8, 261, False), (9, 261, True),
                             (118, 414, True), (119, 414, False),
                             (64, 260, False), (64, 415, False)):
            assert (await sample(left + x, y))[:2] == (int(inside), 0)

    rank_glyphs = {**{rank: rank + 1 for rank in range(2, 10)},
                   11: 20, 12: 27, 13: 21, 14: 11}
    for slot in range(5):
        left = 128 * slot
        for suit in range(4):
            red = int(suit in (1, 2))
            for rank in range(2, 15):
                dut.card_values.value = ((suit << 4) | rank) << (6 * slot)
                rank_cells = ((40, 2), (64, 1)) if rank == 10 else ((52, rank_glyphs[rank]),)
                for x, glyph in rank_cells:
                    assert await sample(left + x, 304) == (1, 1, glyph, 0, 0, red)
                    assert await sample(left + x + 23, 327) == (1, 1, glyph, 11, 11, red)
                assert await sample(left + 52, 352) == (1, 1, 37 + suit, 0, 0, red)
                assert await sample(left + 75, 375) == (1, 1, 37 + suit, 11, 11, red)
                for x, y in ((12, 270), (64, 303), (64, 328), (76, 352), (64, 376)):
                    assert (await sample(left + x, y))[:2] == (1, 0)
