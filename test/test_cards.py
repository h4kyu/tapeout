"""Card boundaries, compact rank IDs, suit colors, and rotated indices."""
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
    for y in (0, 260, 261, 270, 414, 415, 479, 480):
        for x in range(640):
            result = await sample(x, y)
            inside = 261 <= y < 415 and any(23 + 121*i <= x < 133 + 121*i for i in range(5))
            assert result[:2] == (int(inside), 0), (x, y, result)

    for suit in range(4):
        for rank in range(2, 15):
            card = suit * 16 + rank
            dut.card_values.value = sum(card << (6*i) for i in range(5))
            expected_rank = rank + 1 if rank < 10 else {11: 20, 12: 27, 13: 21, 14: 11}.get(rank)
            for i in range(5):
                requests = [(11,24,37+suit),(22,35,37+suit)] if rank in (11,12,13) else []
                if rank == 10:
                    requests += [(5, 8, 2), (16, 19, 2), (17, 8, 1), (28, 19, 1)]
                else:
                    requests += [(11, 8, expected_rank), (22, 19, expected_rank)]
                for x, y, character in requests:
                    gx = (x-5) % 12 if rank == 10 and y < 20 else x-11
                    gy = y-(8 if y < 20 else 24)
                    for rotated in (False, True):
                        local_x, local_y = (109-x, 153-y) if rotated else (x, y)
                        result = await sample(23+121*i+local_x, 261+local_y)
                        assert result == (1, 1, character, gx, gy, int(suit in (1, 2))), (card, i, rotated, result)
                for x, y in ((11, 20), (5, 36)):
                    assert (await sample(23+121*i+x, 261+y))[:2] == (1, 0)

    distinct = (2, 26, 44, 61, 14)
    dut.card_values.value = sum(card << (6*i) for i, card in enumerate(distinct))
    for i, card in enumerate(distinct):
        rank = card & 15
        x = 5 if rank == 10 else 11
        expected = {2: 3, 10: 2, 12: 27, 13: 21, 14: 11}[rank]
        assert (await sample(23+121*i+x, 261+8))[2] == expected

    for suit in range(4):
        for rank in (0, 1, 15):
            dut.card_values.value = suit*16+rank
            for x, y in ((11, 8), (11, 24), (98, 145), (98, 129)):
                assert (await sample(23+x, 261+y))[:2] == (1, 0)

    # Count every occupied pip cell and independently check traditional layouts.
    for rank in range(2, 15):
        dut.card_values.value = 32+rank  # Hearts
        cells = set()
        for row in range(7):
            for col, x in enumerate((27,49,71)):
                value = await sample(23+x, 261+32+14*row)
                if rank <= 10 and value[1]:
                    assert value[2] == 39
                    cells.add((row,col))
        if rank <= 10:
            assert len(cells) == rank, (rank,cells)
            if rank in (2,3):
                assert all(col == 1 for _,col in cells)
            else:
                assert {(0,0),(0,2),(6,0),(6,2)} <= cells
        if rank == 14:
            for x,y,gx,gy in ((49,71,0,0),(60,82,11,11)):
                assert (await sample(23+x,261+y))[1:5] == (1,39,gx,gy)
            for x,y in ((48,71),(61,71),(49,70),(49,83)):
                assert (await sample(23+x,261+y))[:2] == (1,0)
        if rank in (11,12,13):
            char = {11:20,12:27,13:21}[rank]
            for x,y,gx,gy in ((31,53,0,0),(34,56,0,0),(78,100,11,11)):
                assert (await sample(23+x,261+y))[1:5] == (1,char,gx,gy)
            for x,y in ((31,52),(79,53),(31,101)):
                assert (await sample(23+x,261+y))[:2] == (1,0)
