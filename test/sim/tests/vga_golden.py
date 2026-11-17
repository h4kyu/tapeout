"""Fixed-cycle renderer replay and RGB golden images; no GUI/image dependency.

Run `python3 -m sim.tests.vga_golden --update` to deliberately replace fixtures.
Tests never update them. Only the filter-0 RGB8 PNG format emitted by Frame is
accepted here; this is a fixture reader, not a general PNG decoder.
"""
import asyncio
from dataclasses import asdict
import json
from pathlib import Path
import struct
import sys
import zlib

from sim.native_vga import rgb
from sim.poker_sim import PokerSim
from sim.vga_capture import FRAME_CLOCKS, Frame

FIXTURES = Path(__file__).resolve().parents[1] / 'fixtures' / 'vga'
# Each case starts with reset's 3 asserted + 3 released cycles. Clean presses
# are 9 high + 9 low cycles (debounce=5). No wall-clock waits or state polling.
CASES = (
    ('reset', 42, False, (), False, 0, 0),
    ('dealt', 42, True, (), False, 2, 0),
    ('held', 42, True, (1, 3), False, 2, 0),
    ('win', 23, True, (1, 2, 3, 4, 5), True, 5, 10),
    ('game-over', 1, True, (1, 2, 3, 4, 5), True, 5, 0),
)


def fixture_rgb(path):
    encoded = Path(path).read_bytes()
    assert encoded[:8] == b'\x89PNG\r\n\x1a\n'
    offset, compressed = 8, bytearray()
    while offset < len(encoded):
        size = struct.unpack_from('>I', encoded, offset)[0]
        kind = encoded[offset+4:offset+8]
        data = encoded[offset+8:offset+8+size]
        crc = struct.unpack_from('>I', encoded, offset+8+size)[0]
        assert crc == zlib.crc32(kind + data) & 0xffffffff
        if kind == b'IHDR':
            assert struct.unpack('>IIBBBBB', data) == (640, 480, 8, 2, 0, 0, 0)
        elif kind == b'IDAT':
            compressed.extend(data)
        offset += size + 12
    decoded = zlib.decompress(compressed)
    stride = 640 * 3 + 1
    assert len(decoded) == 480 * stride
    assert all(decoded[y*stride] == 0 for y in range(480))
    return b''.join(decoded[y*stride+1:(y+1)*stride] for y in range(480))


async def replay(sim, read_rgb):
    """Replay exactly the same input/clock schedule on either backend."""
    assert sim.debounce_cycles == 5
    images, records = {}, {}
    for name, seed, deal, holds, draw, state, payout in CASES:
        await sim.reset(seed)
        if deal:
            await sim.press_deal_draw()
            await sim.advance(256)
        if holds:
            await sim.set_holds(*holds)
        if draw:
            await sim.press_deal_draw()
            await sim.advance(256)
        # The first frame can contain a partial update; the second is complete.
        await sim.advance(2 * FRAME_CLOCKS)
        snapshot = sim.snapshot()
        assert snapshot.state == state and snapshot.payout == payout, (name, snapshot)
        images[name] = read_rgb()
        assert len(images[name]) == 640 * 480 * 3
        records[name] = dict(seed=seed, holds=list(holds), deal=deal, draw=draw,
                             cycles=sim.cycles, accepted_presses=sim.accepted_presses,
                             snapshot=asdict(snapshot))
    return images, records


def check_fixtures(images, records):
    # JSON round-trip normalizes Snapshot.cards' tuple to the stored array.
    assert json.loads(json.dumps(records)) == json.loads((FIXTURES / 'schedule.json').read_text())
    for name, pixels in images.items():
        assert pixels == fixture_rgb(FIXTURES / f'{name}.png'), f'{name}: rendered RGB changed'


async def native_replay():
    sim = PokerSim.native()
    try:
        images, records = await replay(sim, lambda: rgb(sim.driver.latest_rgba()[1]))
        assert sim.driver.metrics().errors == 0
        return images, records
    finally:
        sim.close()


if __name__ == '__main__':
    if sys.argv[1:] != ['--update']:
        raise SystemExit('Use --update to deliberately replace the VGA baselines')
    images, records = asyncio.run(native_replay())
    FIXTURES.mkdir(parents=True, exist_ok=True)
    for name, pixels in images.items():
        Frame(0, pixels).save(FIXTURES / f'{name}.png')
    (FIXTURES / 'schedule.json').write_text(json.dumps(records, indent=2) + '\n')
    print(f'Updated {len(images)} golden frames in {FIXTURES}')
