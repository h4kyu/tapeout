"""Generate the chip's pixel lookup from the reviewed {character,row} font.

    git show 5b52905:src/font_rom.v > /tmp/font-source.v
    python3 -m sim.synthesis.font_columns /tmp/font-source.v --output ../src/font_rom.v

Column zero is the least significant bit of the original 12-bit row.
"""
import argparse
from collections import defaultdict
from pathlib import Path
import re


def generate(source):
    pattern = r"((?:\s*\{6'd\d+, 4'd\d+\}[:,][^\n]*\n)+)\s*font_row = 12'b([01]+);"
    rows = {}
    for addresses, bitmap in re.findall(pattern, source):
        for character, row in re.findall(r"6'd(\d+), 4'd(\d+)", addresses):
            rows[int(character), int(row)] = int(bitmap, 2)
    if len(rows) != 404:
        raise ValueError("Expected the 404 nonblank glyph rows of the reviewed font")

    header = source[:source.index("// Character IDs:")]
    declarations = []
    masks = {}

    def select(axis, values):
        key = axis, tuple(values)
        if key not in masks:
            name = f"mask{len(masks)}"
            width = 6 if axis == "character" else 4
            expression = " || ".join(f"({axis}=={width}'d{v})" for v in values)
            declarations.append(f"wire {name} = {expression};")
            masks[key] = name
        return masks[key]

    terms = []
    for character in range(1, 41):
        groups = defaultdict(list)
        for row in range(12):
            columns = tuple(i for i in range(12) if rows.get((character, row), 0) & (1 << i))
            if columns:
                groups[columns].append(row)
        patterns = [f"({select('row', lines)} & {select('col', columns)})"
                    for columns, lines in groups.items()]
        terms.append(f"({select('character', [character])} & ({' | '.join(patterns)}))")

    modules = """// Full-row interface for font inspection. The chip requests one pixel directly.
module font_rom(input wire [5:0] character, input wire [3:0] row,
                output wire [11:0] pixels);
    for (genvar bit_index=0; bit_index<12; bit_index=bit_index+1) begin : columns
        font_ink glyph(.character(character), .row(row), .col(4'(bit_index)),
                       .ink(pixels[bit_index]));
    end
endmodule

module font_ink(input wire [5:0] character, input wire [3:0] row, col, output wire ink);
"""
    return header + modules + "\n".join(declarations) + "\nassign ink = " + " |\n".join(terms) + ";\nendmodule\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(generate(args.source.read_text()))
