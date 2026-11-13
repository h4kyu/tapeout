"""Incremental Verilator shared-library build; no Python extension dependencies."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

SIM_ROOT = Path(__file__).resolve().parent
TEST_ROOT = SIM_ROOT.parent


def build(debounce=5):
    if debounce < 1:
        raise ValueError('Debounce cycles must be positive')
    for tool in ('verilator', 'g++', 'make'):
        if not shutil.which(tool):
            raise RuntimeError(f'Missing {tool}: VGA playback and capture require Verilator, g++, and make')
    sources = [TEST_ROOT.parent / 'src' / name for name in (
        'project.v', 'debounce.v', 'poker_inputs.v', 'prng.v', 'poker_dealer.v',
        'poker_evaluator.v', 'poker_core.v', 'vga.v')]
    sources += sorted((SIM_ROOT / 'native').glob('*'))
    flags = ['--timescale', '1ns/1ns', '-O3', '-CFLAGS', '-O3 -fPIC', '-LDFLAGS', '-shared',
             '-Wno-fatal', '--top-module', 'poker_native', f'-GDEBOUNCE_CYCLES={debounce}']
    version = subprocess.check_output(['verilator', '--version']).decode().strip()
    compiler = subprocess.check_output(['g++', '--version']).decode().splitlines()[0]
    digest = hashlib.sha256(json.dumps([flags, version, compiler]).encode())
    digest.update(Path(__file__).read_bytes())
    for source in sources:
        digest.update(source.name.encode() + source.read_bytes())
    directory = TEST_ROOT / 'sim_build' / 'native' / digest.hexdigest()[:20]
    library = directory / 'libpoker.so'
    if not library.exists():
        directory.mkdir(parents=True, exist_ok=True)
        start = time.perf_counter()
        command = ['verilator', '--cc', '--exe', '--build', '-j', str(min(4, os.cpu_count() or 1)),
                   '--Mdir', str(directory), '-o', str(library), *flags,
                   *(str(s) for s in sources if s.suffix in ('.v', '.sv', '.cpp'))]
        with (directory / 'build.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f'Native build failed; see {directory / "build.log"}\n'
                               + (directory / 'build.log').read_text()[-4000:])
        (directory / 'build.json').write_text(json.dumps({
            'build_seconds': time.perf_counter() - start, 'verilator': version,
            'compiler': compiler, 'debounce_cycles': debounce}, indent=2))
    return library


if __name__ == '__main__':
    try:
        print(build(int(os.environ.get('VGA_DEBOUNCE_CYCLES', '5'))))
    except (RuntimeError, ValueError) as error:
        raise SystemExit(str(error)) from None
