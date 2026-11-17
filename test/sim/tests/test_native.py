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
