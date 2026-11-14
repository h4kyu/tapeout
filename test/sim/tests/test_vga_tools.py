"""Fast host-side tests; included in make test-sim, no simulator needed."""

import json
from queue import Empty
import struct
import urllib.error
import urllib.request
import zlib

import pytest

from sim.vga_capture import VGACapture, png_bytes
from sim.vga_viewer import ViewerState, start_server


def pins(x, y, rgb=(0, 0, 0)):
    r, g, b = rgb
    return (int(not (656 <= x < 752)) << 7 | (b & 1) << 6
            | (g & 1) << 5 | (r & 1) << 4
            | int(not (490 <= y < 492)) << 3 | (b >> 1) << 2
            | (g >> 1) << 1 | r >> 1)


def test_external_sync_capture_pixel_alignment_and_palette():
    capture = VGACapture()
    # Enter mid-frame, proving that incomplete frames are discarded.
    for row in range(200, 1005):
        y = row % 525
        for x in range(800):
            rgb = (x % 4, y % 4, (x + y) % 4) if x < 640 and y < 480 else (0, 0, 0)
            capture.sample(pins(x, y, rgb))
    assert capture.frames == 1
    assert capture.errors == 0
    assert len(capture.latest.rgb) == 640 * 480 * 3
    for x, y in ((0, 0), (1, 0), (639, 0), (0, 1), (321, 257), (639, 479)):
        offset = (y * 640 + x) * 3
        assert capture.latest.rgb[offset:offset + 3] == bytes(
            value * 85 for value in (x % 4, y % 4, (x + y) % 4))
    capture.sample(0, reset=True)
    assert capture.latest is None and capture.x is None


def test_stub_unknown_pins_and_bad_blanking():
    capture = VGACapture()
    for _ in range(100):
        capture.sample(0)
    assert capture.latest is None and "Waiting" in capture.status
    capture.sample(None)
    assert capture.errors == 1 and "X/Z" in capture.status
    # Acquire horizontal and vertical lock, then introduce a colored porch.
    for y in range(489, 491):
        for x in range(800):
            capture.sample(pins(x, y))
    capture.sample(pins(0, 491, (3, 0, 0)))
    assert "blanking" in capture.status and capture.y is None


def test_wrong_sync_width_is_rejected():
    capture = VGACapture()
    for x in range(800):
        capture.sample(pins(x, 100))
    # A low edge one pixel early must not be accepted as valid timing.
    for x in range(656):
        capture.sample(pins(x, 101) & (~128 if x == 655 else 255))
    assert capture.errors and capture.x is None


def test_short_vertical_sync_is_rejected():
    capture = VGACapture()
    for y in (489, 490):
        for x in range(800):
            capture.sample(pins(x, y))
    # VSYNC rises after only one low line instead of two.
    capture.sample(pins(0, 491) | 8)
    assert capture.y is None and "VSYNC width" in capture.status


def test_png_encoding():
    rgb = bytes((255, 0, 85, 0, 170, 255))
    encoded = png_bytes(rgb, 2, 1)
    assert encoded[:8] == b"\x89PNG\r\n\x1a\n"
    offset, decoded = 8, b""
    while offset < len(encoded):
        length = struct.unpack(">I", encoded[offset:offset + 4])[0]
        kind = encoded[offset + 4:offset + 8]
        data = encoded[offset + 8:offset + 8 + length]
        crc = struct.unpack(">I", encoded[offset + 8 + length:offset + 12 + length])[0]
        assert crc == zlib.crc32(kind + data) & 0xFFFFFFFF
        if kind == b"IDAT":
            decoded += zlib.decompress(data)
        offset += 12 + length
    assert decoded == b"\0" + rgb
    with pytest.raises(ValueError):
        png_bytes(b"bad")


def test_viewer_transport_and_command_validation():
    state = ViewerState()
    server = start_server(state, 0)
    url = f"http://127.0.0.1:{server.server_port}"
    try:
        assert b"<canvas" in urllib.request.urlopen(url).read()
        assert urllib.request.urlopen(url + "/frame.png").status == 204
        state.publish({"frame": 1, "message": "ready"}, png=b"png")
        assert json.load(urllib.request.urlopen(url + "/state"))["frame"] == 1
        assert urllib.request.urlopen(url + "/frame.png").read() == b"png"
        request = urllib.request.Request(url + "/input", data=b'{"control":"hold","index":1}', method="POST")
        assert urllib.request.urlopen(request).status == 202
        assert state.inputs.get_nowait() == {"control": "hold", "index": 1}
        request = urllib.request.Request(url + "/input", data=b'{"control":"shell"}', method="POST")
        with pytest.raises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request)
        assert error.value.code == 400
        with pytest.raises(Empty):
            state.inputs.get_nowait()
    finally:
        server.shutdown()
        server.server_close()


def test_raw_frames_png_download_and_occupied_port():
    state = ViewerState()
    server = start_server(state, 0)
    url = f"http://127.0.0.1:{server.server_port}"
    try:
        assert urllib.request.urlopen(url + '/frame.rgba').status == 204
        assert state.take_frame_request() and not state.take_frame_request()
        rgba = bytes((255, 0, 85, 255)) * (640 * 480)
        state.publish_frame(17, rgba)
        response = urllib.request.urlopen(url + '/frame.rgba?after=16')
        assert response.headers['X-Frame-Number'] == '17'
        assert response.read() == rgba
        assert urllib.request.urlopen(url + '/frame.rgba?after=17').status == 204
        assert urllib.request.urlopen(url + '/frame.png').read() == png_bytes(
            bytes((255, 0, 85)) * (640 * 480))
        with pytest.raises(RuntimeError, match='already in use'):
            start_server(ViewerState(), server.server_port)
        state.publish({'reset': 1}, clear=True)
        assert urllib.request.urlopen(url + '/frame.rgba').status == 204
    finally:
        server.shutdown()
        server.server_close()


def test_physical_input_validation_and_no_game_state_policy():
    from sim.board_controls import BoardControls, validate_input

    class Pins:
        holds = 0
        deal_pressed = False
        reset_active = False
        def set_switches(self, mask): self.holds = mask
        def set_deal_level(self, pressed): self.deal_pressed = pressed
        def set_reset_level(self, pressed): self.reset_active = pressed
        def snapshot(self): raise AssertionError("Live input handling must not read game state")

    sim = Pins()
    board = BoardControls(sim)
    board.apply({"control": "deal", "pressed": True})
    board.apply({"control": "hold", "index": 2})
    assert sim.deal_pressed and sim.holds == 2
    board.apply({"control": "reset", "pressed": True})
    assert sim.reset_active and sim.deal_pressed and sim.holds == 2
    board.apply({"control": "deal", "pressed": False})
    assert not sim.deal_pressed
    assert not board.apply({"control": "quit"})
    for event in (None, {}, {"control":"hold","index":True},
                  {"control":"hold","index":6}, {"control":"deal","pressed":1},
                  {"control":"reset","pressed":False,"seed":42}, {"control":"profile"}):
        with pytest.raises(ValueError):
            validate_input(event)


def test_terminal_keeps_clocking_between_manual_level_changes():
    import asyncio
    import io
    import os
    import pty
    import termios
    from sim.board_controls import run_terminal

    class Sim:
        holds = 0
        deal_pressed = False
        reset_active = False
        seed = 53
        cycles = 0
        accepted_presses = 0
        debounce_cycles = 5
        def set_switches(self, mask): self.holds = mask
        def set_deal_level(self, pressed): self.deal_pressed = pressed
        def set_reset_level(self, pressed): self.reset_active = pressed
        def snapshot(self): return self
        def ascii(self): return "Read-only diagnostics"
        async def advance(self, cycles):
            self.cycles += cycles
            await asyncio.sleep(0)

    async def exercise():
        sim = Sim()
        master, slave = pty.openpty()
        previous = termios.tcgetattr(slave)
        async def wait_for(predicate):
            while not predicate():
                await asyncio.sleep(0)
        async def controls():
            await wait_for(lambda: sim.cycles >= 8000)
            os.write(master, b" ")
            await wait_for(lambda: sim.deal_pressed)
            before = sim.cycles
            await wait_for(lambda: sim.cycles >= before + 8000)
            assert sim.deal_pressed, "No automatic release waveform"
            os.write(master, b"1r")
            await wait_for(lambda: sim.holds == 1 and sim.reset_active)
            assert sim.seed == 53 and sim.deal_pressed
            os.write(master, b"r ")
            await wait_for(lambda: not sim.reset_active and not sim.deal_pressed)
            os.write(master, b"q")
        try:
            with os.fdopen(os.dup(slave), "r") as keyboard:
                await asyncio.wait_for(asyncio.gather(
                    run_terminal(sim, keyboard, io.StringIO()), controls()), timeout=3)
            assert sim.cycles >= 16000 and sim.holds == 1
            assert termios.tcgetattr(slave) == previous
        finally:
            os.close(master)
            os.close(slave)

    asyncio.run(exercise())
