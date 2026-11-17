"""Stage a source snapshot and map it to real GF180 cells, including latch/ICG cells.

Run from test/: python3 -m sim.synthesis.area --liberty /path/to/tt_025C_3v30.lib
The output is a mapped-cell estimate, not placement/CTS or timing signoff.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
RECIPE = Path(__file__).with_name('area.abc')
TOP = 'tt_um_h4kyu_video_poker'
USABLE_CORE = 51966.97


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--liberty', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'test/output/area')
    parser.add_argument('--yosys', default='yosys')
    parser.add_argument('--reference-dir',type=Path,help='Optional exported baseline tree')
    parser.add_argument('--mapping',choices=('experiment','default'),default='experiment')
    parser.add_argument('--reference', help='Read src/*.v from this Git revision instead of the working tree')
    args = parser.parse_args()
    if not args.liberty.is_file():
        parser.error(f'Liberty file does not exist: {args.liberty}')
    tool = shutil.which(args.yosys)
    if tool is None:
        parser.error(f'Missing synthesis tool: {args.yosys}')
    output = args.output.resolve()
    rtl = output / 'rtl'
    rtl.mkdir(parents=True, exist_ok=True)
    for old in rtl.glob('*.v'):
        old.unlink()
    if args.reference and args.reference_dir:
        parser.error('Choose --reference or --reference-dir')
    if args.reference_dir:
        sources={str(path.relative_to(args.reference_dir)):path.read_bytes() for path in sorted((args.reference_dir/'src').glob('*.v'))}
    elif args.reference:
        names = subprocess.check_output(
            ['git', 'ls-tree', '-r', '--name-only', args.reference, '--', 'src'], cwd=ROOT).decode().splitlines()
        sources = {name: subprocess.check_output(['git', 'show', f'{args.reference}:{name}'], cwd=ROOT)
                   for name in names if name.endswith('.v')}
    else:
        sources = {str(path.relative_to(ROOT)): path.read_bytes() for path in sorted((ROOT / 'src').glob('*.v'))}
    for name, data in sources.items():
        (rtl / Path(name).name).write_bytes(data)
    liberty = args.liberty.read_bytes()
    (output / 'target.lib').write_bytes(liberty)
    recipe = RECIPE.read_bytes() if args.mapping=='experiment' else b''
    (output / 'area.abc').write_bytes(recipe)
    # Relative staged paths also work in YoWASP's restricted filesystem.
    abc_script=' -script area.abc' if args.mapping=='experiment' else ''
    script = f'''read_verilog -sv rtl/*.v
read_liberty -lib target.lib
synth -top {TOP} -flatten -noabc
dfflibmap -liberty target.lib
abc -liberty target.lib -D 40000{abc_script}
clean
check -assert
tee -o stats.json stat -json -liberty target.lib
select -clear
select {TOP}
write_verilog -noattr -noexpr -selected mapped.v
'''
    (output / 'area.ys').write_text(script)
    version = subprocess.check_output([tool, '-V']).decode().strip()
    started = time.monotonic()
    with (output / 'synthesis.log').open('w') as log:
        result = subprocess.run([tool, '-Q', '-T', '-s', 'area.ys'], cwd=output, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise SystemExit(f'Synthesis failed; see {output / "synthesis.log"}')
    statistics = json.loads((output / 'stats.json').read_text())['design']
    counts = statistics['num_cells_by_type']
    unknown = [kind for kind in counts if not kind.startswith('gf180mcu_fd_sc_mcu7t5v0__')]
    if unknown:
        raise SystemExit(f'Unmapped/unaccounted cells: {unknown}')
    area = statistics['area']
    summary = dict(mapped_area_um2=area, usable_core_um2=USABLE_CORE,
                   utilization_percent=area / USABLE_CORE * 100,
                   margin_um2=USABLE_CORE-area, mapped_cells=statistics['num_cells'],
                   cell_counts=counts, yosys=version,
                   source_sha256={name: sha(data) for name, data in sources.items()},
                   liberty_sha256=sha(liberty), abc_recipe_sha256=sha(recipe),
                   reference=args.reference or (str(args.reference_dir) if args.reference_dir else None), mapping=args.mapping, seconds=time.monotonic()-started,
                   physical_fit_verified=False, timing_verified=False,
                   note=('Area-focused mapping; 40 ns is passed to ABC but amap does not enforce timing closure.' if args.mapping=='experiment' else 'Default ABC mapping with 40 ns target.')+' No placement, CTS, parasitics, or all-corner STA.')
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'{area:.4f} um2; {summary["utilization_percent"]:.3f}% of usable core; '
          f'{summary["margin_um2"]:.4f} um2 margin; {summary["mapped_cells"]} cells')
    print(f'Receipt: {output / "summary.json"}')
    print('Not a physical-fit or timing signoff result.')


if __name__ == '__main__':
    main()
