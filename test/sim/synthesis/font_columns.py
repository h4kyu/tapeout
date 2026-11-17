"""Regenerate the factored row lookup from the baseline row-case font source.

Example: git show 5b52905:src/font_rom.v > /tmp/font-source.v
         python3 -m sim.synthesis.font_columns /tmp/font-source.v --output ../src/font_rom.v
Input format is the baseline's explicit {character,row}: 12-bit-row cases.
Font artwork remains subject to docs/press-start-2p-OFL.txt.
"""
import argparse
from pathlib import Path
import re


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    original=args.source.read_text()
    rows={}
    pattern=r"((?:\s*\{6'd\d+, 4'd\d+\}[:,][^\n]*\n)+)\s*font_row = 12'b([01]+);"
    for group,bits in re.findall(pattern,original):
        for character,row in re.findall(r"6'd(\d+), 4'd(\d+)",group):
            rows[int(character),int(row)]=int(bits,2)
    if not rows: parser.error('No baseline-format glyph rows found')
    header=original[:original.index('// Character IDs:')]
    text=header+'module font_rom(input wire [5:0] character,input wire [3:0] row,output wire [11:0] pixels);\n'
    for character in range(1,41):
        text+=f"wire c{character} = character == 6'd{character};\n"
    masks={}
    outputs=[]
    for bit in range(12):
        terms=[]
        for character in range(1,41):
            bitmap=sum(((rows.get((character,row),0)>>bit)&1)<<row for row in range(12))
            if not bitmap: continue
            if bitmap not in masks: masks[bitmap]=len(masks)
            terms.append(f'(c{character} & r{masks[bitmap]})')
        outputs.append(f'assign pixels[{bit}] = '+(' | '.join(terms) or "1'b0")+';\n')
    for bitmap,index in masks.items():
        text+=f"wire r{index} = (16'h{bitmap:04x} >> row) & 1'b1;\n"
    args.output.write_text(text+''.join(outputs)+'endmodule\n')


if __name__=='__main__': main()
