"""Verify every payout-panel pixel against labels and the independent font ROM."""

import cocotb
from cocotb.triggers import Timer

from sim.poker_sim import PokerSim
from sim.vga_capture import VGACapture, FRAME_CLOCKS
from test_core import PAYOUTS


@cocotb.test()
async def payout_sheet_text(dut):
    if int(dut.GATE_LEVEL.value):
        dut._log.info("Payout capture uses the RTL batched clock driver")
        return

    labels = (
        "ROYAL FLUSH", "STRAIGHT FLUSH", "FOUR OF A KIND", "FULL HOUSE",
        "FLUSH", "STRAIGHT", "THREE OF A KIND", "TWO PAIR", "JACKS OR BETTER",
    )
    characters = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    glyphs = {}
    for character in characters:
        dut.font_character.value = characters.index(character)
        rows = []
        for row in range(12):
            dut.font_row.value = row
            await Timer(1, unit="ns")
            rows.append(int(dut.font_pixels.value))
        glyphs[character] = rows

    capture = VGACapture()
    sim = PokerSim(dut, batch_clocks=True)
    sim.observe_cycles(capture.sample)
    try:
        await sim.reset()
        for _ in range(3 * FRAME_CLOCKS // 800):
            await sim.advance(800)
            if capture.latest:
                break
        assert capture.latest is not None, capture.status
        assert capture.errors == 0
        actual = capture.latest.rgb

        # Independent reference starts with flat panels and stamps strings.
        for left, width, background, origin, strings in (
            (28, 459, (170, 170, 170), 35, labels),
            (491, 121, (255, 0, 0), 555,
             tuple(str(PAYOUTS[category]).rjust(4) for category in range(9, 0, -1))),
        ):
            expected = bytearray(background) * (width * 170)
            for line, string in enumerate(strings):
                for column, character in enumerate(string):
                    for gy, bits in enumerate(glyphs[character]):
                        for gx in range(12):
                            if bits & (1 << (11 - gx)):
                                x = origin + 12 * column + gx - left
                                y = 29 + 18 * line + gy - 21
                                offset = (y * width + x) * 3
                                expected[offset:offset + 3] = b"\xff\xff\xff"
            for y in range(170):
                begin = ((21 + y) * 640 + left) * 3
                assert actual[begin:begin + width * 3] == expected[y * width * 3:(y + 1) * width * 3], (
                    "Payout text or row-gap mismatch", left, 21 + y)
    finally:
        sim.close()
