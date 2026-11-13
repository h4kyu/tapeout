"""Uncapped native RTL viewer, deterministic capture, and separated benchmarks."""
import asyncio
from dataclasses import asdict
import json
import os
from pathlib import Path
from queue import Empty
import time

from sim.build_native import build
from sim.poker_sim import PokerSim
from sim.poker_controls import GameScreen, PokerTerminal
from sim.vga_capture import Frame, FRAME_CLOCKS
from sim.vga_viewer import ViewerState, start_server


def rgb(rgba):
    out = bytearray(640 * 480 * 3)
    out[0::3] = rgba[0::4]; out[1::3] = rgba[1::4]; out[2::3] = rgba[2::4]
    return bytes(out)


def status(driver):
    s = driver.metrics()
    messages = ('Waiting for VGA sync (the inactive stub produces no frames)',
                'VGA sync locked; scanning next frame', '640×480 VGA frame captured from output pins',
                'Invalid line period', 'Invalid HSYNC width', 'VSYNC edge not at line start',
                'Invalid VSYNC width or frame period', 'RGB is not black during VGA blanking')
    return s, messages[s.status]


async def benchmark(debounce):
    report = {'build': json.loads(build(debounce).with_name('build.json').read_text())}
    for decode in (False, True):
        sim = PokerSim.native(debounce, decode)
        try:
            await sim.reset()
            start = time.perf_counter()
            while not sim.driver.metrics().ready and sim.cycles < 3 * FRAME_CLOCKS:
                await sim.advance(16384)
                if not decode and sim.cycles >= 2 * FRAME_CLOCKS:
                    break
            first = time.perf_counter() - start
            if decode and not sim.driver.metrics().ready:
                raise TimeoutError('Benchmark requires an active renderer producing complete VGA frames')
            await sim.advance(10 * FRAME_CLOCKS)
            start = time.perf_counter()
            await sim.advance(120 * FRAME_CLOCKS)
            elapsed = time.perf_counter() - start
            s = sim.driver.metrics()
            report['capture' if decode else 'execution'] = {
                'clocks_per_second': 120 * FRAME_CLOCKS / elapsed,
                'generated_fps': 120 / elapsed, 'first_frame_seconds': first if decode else None,
                'measurement_seconds': elapsed, 'sync_errors': s.errors,
            }
        finally:
            sim.close()
    path = Path(os.environ.get('VGA_BENCHMARK_OUTPUT', 'output/vga-benchmark.json'))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)
    if report['capture']['clocks_per_second'] < 12_600_000:
        raise RuntimeError('Native decoding missed the 12.6 MHz / 30 FPS target; profile before accepting')


async def run():
    debounce = int(os.environ.get('VGA_DEBOUNCE_CYCLES', '5'))
    if os.environ.get('VGA_BENCHMARK') == '1':
        await benchmark(debounce)
        return
    sim = PokerSim.native(debounce)
    server = None
    try:
        await sim.reset(int(os.environ.get('VGA_SEED', '42')))
        terminal = PokerTerminal(sim, output=lambda *_: None)
        for command in filter(str.strip, os.environ.get('VGA_COMMANDS', '').split(';')):
            await terminal.command(command)
        if os.environ.get('VGA_HEADLESS') == '1':
            limit = int(os.environ.get('VGA_MAX_CYCLES', str(3 * FRAME_CLOCKS)))
            start = sim.cycles
            initial_frame = sim.driver.metrics().frames
            while sim.cycles - start < limit:
                # Match Cocotb capture schedule for exact screenshot/cycle comparisons.
                await sim.advance(min(800, limit - (sim.cycles - start)))
                s, message = status(sim.driver)
                if s.ready and s.frames > initial_frame:
                    number, rgba = sim.driver.latest_rgba()
                    path = Path(os.environ.get('VGA_OUTPUT', 'output/vga.png'))
                    Frame(number, rgb(rgba)).save(path)
                    path.with_suffix('.json').write_text(json.dumps({
                        'width': 640, 'height': 480, 'cycles': sim.cycles,
                        'frame': number, 'sync_errors': s.errors,
                        'game': asdict(sim.snapshot()), 'backend': 'verilator'}, indent=2) + '\n')
                    print(f'VGA screenshot: {path.resolve()} ({sim.cycles:,} clocks)')
                    return
            raise TimeoutError(f'No complete VGA frame: {message}')
        viewer = ViewerState()
        server = start_server(viewer, int(os.environ.get('VGA_PORT', '8765')))
        print(f'VGA viewer: http://localhost:{server.server_port} (Verilator, uncapped)\n'
              'Space Deal/Draw | 1-5 Holds | R Reset | B Profile | Q Stop', flush=True)
        screen = GameScreen(sim)
        reset = 0
        next_publish = 0
        rate_start = time.monotonic(); rate_cycles = sim.cycles
        rate_frames = sim.driver.metrics().frames
        clocks_per_second = generated_fps = 0
        while True:
            for _ in range(16):
                try:
                    key = viewer.keys.get_nowait()
                except Empty:
                    break
                if not await screen.key(key):
                    return
                if key == 'r':
                    reset += 1
                    viewer.publish({}, clear=True)
                    rate_start = time.monotonic(); rate_cycles = sim.cycles
                    rate_frames = sim.driver.metrics().frames
            await sim.advance(16384)
            await asyncio.sleep(0)  # Deliver cancellation/interrupts between bounded batches.
            now = time.monotonic()
            # HTTP threads request a copy; only this owner calls the model.
            if viewer.take_frame_request():
                frame = sim.driver.latest_rgba()
                if frame:
                    viewer.publish_frame(*frame)
            if now >= next_publish:
                s, message = status(sim.driver)
                elapsed = now - rate_start
                if elapsed >= 0.5:
                    clocks_per_second = (sim.cycles - rate_cycles) / elapsed
                    generated_fps = (s.frames - rate_frames) / elapsed
                    rate_start = now; rate_cycles = sim.cycles; rate_frames = s.frames
                viewer.publish({'frame': s.frames, 'reset': reset, 'cycles': sim.cycles,
                                'message': message, 'has_frame': bool(s.ready),
                                'details': screen.render().replace('Simulation pauses between keys.', 'Simulation runs uncapped.'),
                                'backend': 'Verilator', 'clocks_per_second': clocks_per_second,
                                'generated_fps': generated_fps, 'sync_errors': s.errors})
                next_publish = now + 0.2
    finally:
        if server:
            server.shutdown(); server.server_close()
        sim.close()


if __name__ == '__main__':
    try:
        asyncio.run(run())
    except (RuntimeError, OSError, ValueError, TimeoutError) as error:
        raise SystemExit(str(error)) from None
    except KeyboardInterrupt:
        pass
