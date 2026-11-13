"""Decode the external Tiny Tapeout VGA pins. No RTL hierarchy or GUI dependencies.

640x480, 800 clocks/line, 525 lines/frame, active-low sync. The active image
begins 48 clocks after HSYNC rises and 33 lines after VSYNC rises.
"""

from dataclasses import dataclass
from pathlib import Path
import struct
import zlib


WIDTH, HEIGHT = 640, 480
LINE_CLOCKS, FRAME_LINES = 800, 525
FRAME_CLOCKS = LINE_CLOCKS * FRAME_LINES


def png_bytes(rgb, width=WIDTH, height=HEIGHT):
    """Encode an RGB8 screenshot using only the Python standard library."""
    if len(rgb) != width * height * 3:
        raise ValueError("RGB buffer size does not match image dimensions")

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    stride = width * 3
    rows = b"".join(b"\0" + rgb[y * stride:(y + 1) * stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


@dataclass(frozen=True)
class Frame:
    number: int
    rgb: bytes

    def png(self):
        return png_bytes(self.rgb)

    def save(self, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.png())


class VGACapture:
    """Acquire sync, discard partial frames, and publish complete visible frames.

    A malformed signal loses lock rather than silently shifting the picture.
    The fixed timing contract deliberately catches errors in this VGA mode.
    """

    def __init__(self):
        self.frames = 0
        self.latest = None
        self.errors = 0
        self.reset()

    def reset(self):
        self.x = self.y = None
        self.previous_h = self.previous_v = None
        self.since_h = None
        self.collecting = False
        self.count = 0
        self.buffer = bytearray(WIDTH * HEIGHT * 3)
        self.latest = None
        self.status = "Waiting for VGA sync (the inactive stub produces no frames)"

    def lose_lock(self, reason):
        self.errors += 1
        self.x = self.y = None
        self.collecting = False
        self.count = 0
        self.status = reason

    def sample(self, pins, reset=False):
        if reset:
            # Avoid reallocating the buffer on each cycle held in reset.
            if self.previous_h is not None or self.latest is not None:
                self.reset()
            return
        if pins is None:
            self.lose_lock("Unknown X/Z on VGA output pins")
            self.previous_h = self.previous_v = None
            return

        h, v = (pins >> 7) & 1, (pins >> 3) & 1
        rising_h = self.previous_h == 0 and h == 1
        vertical_edge = self.previous_v is not None and self.previous_v != v
        if self.since_h is not None:
            self.since_h += 1
        if self.x is not None:
            self.x = (self.x + 1) % LINE_CLOCKS
        if rising_h:
            if self.since_h is not None and self.since_h != LINE_CLOCKS:
                self.lose_lock(f"Invalid line period: {self.since_h}, expected 800 clocks")
            self.since_h = 0
            self.x = 752

        if self.x is not None:
            if h != int(not (656 <= self.x < 752)):
                self.lose_lock("Invalid HSYNC pulse: expected clocks 656..751")
            elif vertical_edge:
                if self.x != 0:
                    self.lose_lock("VSYNC edge is not aligned with the start of a line")
                elif self.y is not None and (self.y + 1) % FRAME_LINES != (492 if v else 490):
                    self.lose_lock("Invalid VSYNC width or frame period: expected 2 sync lines and 525 total lines")
                else:
                    self.y = 492 if v else 490
                    self.collecting = False
                    self.count = 0
                    self.status = ("VGA sync acquired; waiting for a complete frame"
                                   if self.latest is None else "VGA sync locked; scanning next frame")
            elif self.x == 0 and self.y is not None:
                self.y = (self.y + 1) % FRAME_LINES

        if self.x is not None and self.y is not None:
            if v != int(not (490 <= self.y < 492)):
                self.lose_lock("Invalid VSYNC pulse: expected lines 490..491")
            else:
                if self.x == 0 and self.y == 0:
                    self.collecting = True
                    self.count = 0
                r = (((pins >> 0) & 1) << 1) | ((pins >> 4) & 1)
                g = (((pins >> 1) & 1) << 1) | ((pins >> 5) & 1)
                b = (((pins >> 2) & 1) << 1) | ((pins >> 6) & 1)
                if self.x >= WIDTH or self.y >= HEIGHT:
                    if r or g or b:
                        self.lose_lock("RGB is not black during VGA blanking")
                elif self.collecting:
                    offset = (self.y * WIDTH + self.x) * 3
                    self.buffer[offset:offset + 3] = bytes((r * 85, g * 85, b * 85))
                    self.count += 1
                    if self.x == WIDTH - 1 and self.y == HEIGHT - 1:
                        if self.count == WIDTH * HEIGHT:
                            self.frames += 1
                            self.latest = Frame(self.frames, bytes(self.buffer))
                            self.status = "640×480 VGA frame captured from output pins"
                        self.collecting = False

        self.previous_h, self.previous_v = h, v
