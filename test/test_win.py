"""Native footer results: all awards, zero padding, native pixels, and visibility."""
import cocotb
from cocotb.triggers import Timer
from test_core import PAYOUTS


@cocotb.test()
async def win_banner_requests(dut):
    characters = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    dut.status_clk.value = 0
    dut.status_rst_n.value = 0
    dut.status_balance.value = 100
    dut.status_state.value = 5
    dut.status_payout.value = 0
    await Timer(1, unit="ns")
    dut.status_rst_n.value = 1

    async def pixel(x, y):
        dut.status_x.value = x
        dut.status_y.value = y
        await Timer(1, unit="ns")
        return (int(dut.status_text_active.value), int(dut.status_character.value),
                int(dut.status_glyph_x.value), int(dut.status_glyph_y.value))

    for payout in PAYOUTS:
        dut.status_payout.value = payout
        text = f"WIN {payout:04d} " if payout else "GAME OVER"
        for column, character in enumerate(text):
            assert await pixel(256 + 16*column, 448) == (1, characters.index(character), 0, 0)
            assert await pixel(267 + 16*column, 459) == (1, characters.index(character), 11, 11)
        for x, y in ((255,448),(400,448),(320,447),(320,460),(320,340)):
            assert (await pixel(x,y))[0] == 0

    dut.status_payout.value = 5
    for y in range(12):
        for x in range(12):
            assert await pixel(256+x,448+y) == (1,characters.index('W'),x,y)
    for state in (0,1,2,3,4,6,7):
        dut.status_state.value = state
        assert (await pixel(320,448))[0] == 0
    dut.status_state.value = 5
    for payout in range(4096):
        dut.status_payout.value = payout
        assert (await pixel(320,448))[0] == int(payout in PAYOUTS)
