"""Compare the production chip against the prior payout-sheet-free experiment.

From test/: python3 -m sim.synthesis.production_equivalence --reference 9a6b7c0
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", default="9a6b7c0")
    parser.add_argument("--reference-dir", type=Path, help="Exported reference tree")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    if args.reference_dir:
        sources = {p.name: p.read_text() for p in (args.reference_dir / "src").glob("*.v")}
    else:
        names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only",
                                         args.reference, "src"], cwd=root, text=True)
        sources = {Path(n).name: subprocess.check_output(
            ["git", "show", f"{args.reference}:{n}"], cwd=root, text=True)
            for n in names.splitlines() if n.endswith(".v")}
    modules = {name for source in sources.values()
               for name in re.findall(r"^module\s+(\w+)", source, re.MULTILINE)}
    if not modules:
        parser.error("No reference RTL found")
    identifiers = re.compile(r"\b(" + "|".join(sorted(modules)) + r")\b")
    with tempfile.TemporaryDirectory(prefix="poker-production-") as directory:
        work = Path(directory)
        for name, source in sources.items():
            (work / ("gold_" + name)).write_text(identifiers.sub(r"gold_\1", source))
        for source in (root / "src").glob("*.v"):
            shutil.copy(source, work)
        bench = Path(__file__).with_suffix(".sv")
        subprocess.run(["verilator", "-Wno-fatal", "--binary", "--timing", "-j", "4",
                        "--top-module", "production_equivalence",
                        *sorted(work.glob("*.v")), bench], cwd=work, check=True)
        subprocess.run([work / "obj_dir/Vproduction_equivalence"], cwd=work, check=True)


if __name__ == "__main__":
    main()
