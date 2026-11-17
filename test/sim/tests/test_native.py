"""Native-only decoder contracts and build configuration checks."""
import asyncio
import ctypes as C

from sim.native_sim import load_library, FRAME_BYTES
from sim.poker_sim import PokerSim
from sim.tests.test_vga_tools import pins
from sim.vga_capture import VGACapture
from sim.native_vga import rgb


def test_native_decoder_matches_reference_and_rejects_bad_sync():
    lib = load_library()
    handle = lib.capture_create()
    reference = VGACapture()

    def feed(values, reset=False):
        values = bytes(values)
        for value in values:
            reference.sample(value, reset)
        lib.capture_feed(handle, values, len(values), reset)
        metrics = (C.c_uint64 * 3)()
        lib.capture_state(handle, metrics)
        assert tuple(metrics) == (reference.frames, reference.errors, reference.latest is not None)

    try:
        # Initial partial frame and every 2-bit channel value.
        for row in range(200, 1005):
            y = row % 525
            feed(pins(x, y, (x % 4, y % 4, (x+y) % 4) if x < 640 and y < 480 else (0, 0, 0))
                 for x in range(800))
        buffer = (C.c_uint8 * FRAME_BYTES)()
        assert lib.capture_frame(handle, buffer) == reference.frames == 1
        assert rgb(bytes(buffer)) == reference.latest.rgb
        feed([0], True)
        assert reference.latest is None
        # Stub cannot manufacture a frame.
        feed([0] * 2000)
        # Wrong HSYNC width.
        feed(pins(x, 100) for x in range(800))
        feed(pins(x, 101) & (~128 if x == 655 else 255) for x in range(656))
        assert reference.errors
        feed([0], True)
        for y in (489, 490):
            feed(pins(x, y) for x in range(800))
        feed([pins(0, 491) | 8])
        assert 'VSYNC width' in reference.status
        feed([0], True)
        for y in (489, 490):
            feed(pins(x, y) for x in range(800))
        feed([pins(0, 491, (3, 0, 0))])
        assert 'blanking' in reference.status
    finally:
        lib.capture_destroy(handle)


def test_production_debounce_and_large_advance():
    async def play():
        sim = PokerSim.native(debounce_cycles=500000)
        try:
            await sim.reset()
            await sim.press_deal_draw('short')
            assert sim.accepted_presses == 0
            await sim.press_deal_draw()
            await sim.wait_for_state(2)
            assert sim.accepted_presses == 1 and sim.cycles > 1_000_000
        finally:
            sim.close()
    asyncio.run(play())


def test_hold_labels_persist_after_draw_and_clear_next_round():
    from sim.vga_capture import FRAME_CLOCKS

    async def play():
        sim = PokerSim.native()
        baseline = None
        label_pixels = None

        async def check_labels(mask):
            nonlocal baseline, label_pixels
            # Allow an entirely new frame to be scanned after the input change.
            await sim.advance(2 * FRAME_CLOCKS)
            _, frame = sim.driver.latest_rgba()
            payout = frame[:196 * 640 * 4]
            if baseline is None:
                baseline = payout
            else:
                assert payout == baseline, "HOLD request interfered with payout text"
            for card in range(5):
                left = 51 + 121 * card
                region = b"".join(frame[(y * 640 + left) * 4:(y * 640 + left + 54) * 4]
                                  for y in range(246, 258))
                if mask & (1 << card):
                    assert b"\xff\xff\xff\xff" in region, f"Missing HOLD on card {card + 1}"
                    if label_pixels is None:
                        label_pixels = region
                    assert region == label_pixels, "Labels must share the same glyph rendering"
                else:
                    assert region == bytes((0, 170, 0, 255)) * (54 * 12)

        try:
            await sim.reset()
            await check_labels(0)
            await sim.press_deal_draw()
            await sim.wait_for_state(2)
            await sim.set_holds(1, 3)
            await check_labels(0b00101)
            await sim.press_deal_draw()
            await sim.wait_for_state(5)
            # Switch changes during RESULT must not erase frozen hold labels.
            await sim.set_holds(2, 4)
            assert sim.snapshot().holds == 0b00101
            await check_labels(0b00101)
            await sim.set_holds()
            await sim.press_deal_draw()
            await sim.wait_for_state(2)
            assert sim.snapshot().holds == 0
            await check_labels(0)
        finally:
            sim.close()

    asyncio.run(play())


def test_credits_and_bet_track_game_balance():
    from sim.vga_capture import FRAME_CLOCKS

    async def play():
        sim = PokerSim.native()

        async def footer():
            await sim.advance(2 * FRAME_CLOCKS)
            _, frame = sim.driver.latest_rgba()
            def region(left, width):
                return b"".join(frame[(y * 640 + left) * 4:(y * 640 + left + width) * 4]
                                for y in range(446, 458))
            return region(555, 60), region(25, 60)

        try:
            await sim.reset()
            initial_credits, bet = await footer()
            assert b"\xff\xff\x00\xff" in initial_credits
            assert b"\xff\xff\x00\xff" in bet
            await sim.press_deal_draw()
            await sim.wait_for_state(2)
            assert sim.snapshot().balance == 95
            dealt_credits, dealt_bet = await footer()
            assert dealt_credits != initial_credits
            assert dealt_bet == bet
            await sim.reset()
            reset_credits, reset_bet = await footer()
            assert reset_credits == initial_credits
            assert reset_bet == bet
        finally:
            sim.close()

    asyncio.run(play())


def test_hand_message_live_white_final_yellow_and_blank_reset():
    from sim.vga_capture import FRAME_CLOCKS
    from test_core import reference

    async def play():
        sim = PokerSim.native()

        async def message_pixels():
            await sim.advance(2 * FRAME_CLOCKS)
            _, frame = sim.driver.latest_rgba()
            return b"".join(frame[(y * 640 + 170) * 4:(y * 640 + 470) * 4]
                            for y in range(213, 233))

        try:
            # Find a qualifying dealt hand using only seed and real controls.
            for seed in range(256):
                await sim.reset(seed)
                await sim.press_deal_draw()
                await sim.wait_for_state(2)
                category = reference(sim.snapshot().cards)
                if category:
                    break
            else:
                raise AssertionError("No qualifying dealt hand found")
            assert sim.snapshot().category == 0  # Result not latched yet.
            before = await message_pixels()
            assert b"\xff\xff\xff\xff" in before, (seed, category)
            assert b"\xff\xff\x00\xff" not in before
            await sim.set_holds(1, 2, 3, 4, 5)
            await sim.press_deal_draw()
            await sim.wait_for_state(5)
            assert sim.snapshot().category == category
            after = await message_pixels()
            expected = bytearray(before)
            for offset in range(0, len(before), 4):
                if before[offset:offset + 4] == b"\xff\xff\xff\xff":
                    expected[offset:offset + 4] = b"\xff\xff\x00\xff"
            assert after == bytes(expected)
            await sim.reset()
            blank = await message_pixels()
            assert blank == bytes((0, 170, 0, 255)) * (300 * 20)
        finally:
            sim.close()

    asyncio.run(play())


def test_footer_result_shows_win_or_game_over_without_panel():
    from sim.vga_capture import FRAME_CLOCKS
    from test_core import reference

    async def play():
        sim = PokerSim.native()
        green = bytes((0,170,0,255))
        yellow = bytes((255,255,0,255))
        def region(frame,left,top,width,height):
            return b''.join(frame[(y*640+left)*4:(y*640+left+width)*4]
                            for y in range(top,top+height))
        async def frame():
            await sim.advance(2*FRAME_CLOCKS)
            return sim.driver.latest_rgba()[1]
        try:
            for winning in (True,False):
                for seed in range(256):
                    await sim.reset(seed)
                    await sim.press_deal_draw()
                    await sim.wait_for_state(2)
                    if bool(reference(sim.snapshot().cards)) == winning:
                        break
                else:
                    raise AssertionError("No example hand found")
                before = await frame()
                assert region(before,266,446,108,12) == green*(108*12)
                await sim.set_holds(1,2,3,4,5)
                await sim.press_deal_draw()
                await sim.wait_for_state(5)
                assert bool(sim.snapshot().payout) == winning
                after = await frame()
                # Holding all cards keeps their pixels identical: no result
                # rectangle or text is allowed to obscure their faces anymore.
                assert region(after,0,261,640,154) == region(before,0,261,640,154)
                text = region(after,266,446,108,12)
                assert {text[i:i+4] for i in range(0,len(text),4)} == {green,yellow}
                # The old large panel area in the footer contains only green
                # and yellow result pixels, never any gray background.
                footer = region(after,181,428,278,48)
                assert {footer[i:i+4] for i in range(0,len(footer),4)} == {green,yellow}
                for top,height in ((442,4),(458,4)):
                    assert region(after,262,top,116,height) == green*(116*height)
                await sim.set_holds()
                await sim.press_deal_draw()
                await sim.wait_for_state(2)
                assert region(await frame(),266,446,108,12) == green*(108*12)
            await sim.reset()
            assert region(await frame(),266,446,108,12) == green*(108*12)
        finally:
            sim.close()
    asyncio.run(play())


def test_card_indices_rotate_and_use_suit_colors():
    from sim.vga_capture import FRAME_CLOCKS

    async def play():
        sim = PokerSim.native()
        def region(frame, left, top, width, height):
            return b''.join(frame[(y*640+left)*4:(y*640+left+width)*4]
                            for y in range(top, top+height))
        try:
            await sim.reset(23)
            await sim.advance(2*FRAME_CLOCKS)
            _, frame = sim.driver.latest_rgba()
            assert region(frame, 23, 261, 110, 154) == bytes((255,255,255,255))*(110*154)
            await sim.press_deal_draw()
            await sim.wait_for_state(2)
            await sim.advance(2*FRAME_CLOCKS)
            _, frame = sim.driver.latest_rgba()
            for i, card in enumerate(sim.snapshot().cards):
                left = 23+121*i
                top = region(frame, left+5, 269, 24, 12)
                bottom = region(frame, left+81, 395, 24, 12)
                assert top == b''.join(bottom[j:j+4] for j in range(len(bottom)-4, -1, -4))
                colors = {top[j:j+4] for j in range(0, len(top), 4)}
                ink = bytes((255,0,0,255)) if card >> 4 in (1,2) else bytes((0,0,0,255))
                assert colors == {bytes((255,255,255,255)), ink}
                corner = region(frame, left+11, 285, 12, 12)
                if (card & 15) in (11,12,13):
                    assert ink in {corner[j:j+4] for j in range(0,len(corner),4)}
                else:
                    assert corner == bytes((255,255,255,255))*144
                center = region(frame, left+27, 293, 56, 96)
                assert ink in {center[j:j+4] for j in range(0,len(center),4)}
        finally:
            sim.close()
    asyncio.run(play())


def test_renderer_golden_frames():
    from sim.tests.vga_golden import native_replay, check_fixtures
    check_fixtures(*asyncio.run(native_replay()))
