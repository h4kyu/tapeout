"""Four-state, cycle-scheduled core comparison against the pre-experiment RTL.

Requires a full Git clone containing the reference commit and Icarus Verilog.
Run from test/: python3 -m sim.synthesis.core_equivalence --reference 5b52905
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[3]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',default='5b52905')
    parser.add_argument('--reference-dir',type=Path,help='Optional exported baseline tree, for shallow/container checkouts')
    parser.add_argument('--cycles',type=int,default=100000)
    args=parser.parse_args()
    for tool in ('iverilog','vvp'):
        if not shutil.which(tool): parser.error(f'Missing {tool}')
    if args.cycles<1: parser.error('cycles must be positive')
    with tempfile.TemporaryDirectory(prefix='poker-equivalence-') as directory:
        work=Path(directory)
        sources=[]
        for name in ('poker_core','poker_dealer','poker_evaluator'):
            old=(args.reference_dir/'src'/f'{name}.v').read_text() if args.reference_dir else subprocess.check_output(['git','show',f'{args.reference}:src/{name}.v'],cwd=ROOT).decode()
            for dependency in ('poker_core','poker_dealer','poker_evaluator'):
                old=re.sub(r'\b'+dependency+r'\b','gold_'+dependency,old)
            path=work/f'gold_{name}.v';path.write_text(old);sources.append(path)
            sources.append(ROOT/'src'/f'{name}.v')
        wrapper='''`timescale 1ns/1ps
module core_equivalence;
reg clk=0, rst_n=1, deal_draw_pulse=0, prng_ready=0;
reg [4:0] hold_mask=0;
reg [5:0] candidate=0;
integer cycle, seed=32'h5eed1234, noise;
'''
        outputs=[('dealer_ready',1),('cards',30),('dealt_mask',52),('held_cards',5),('state',3),('balance',16),('hand_category',4),('result_category',4),('result_payout',12),('can_deal',1)]
        inputs=['clk','rst_n','deal_draw_pulse','prng_ready','hold_mask','candidate']
        for prefix,module in [('a','gold_poker_core'),('b','poker_core')]:
            for name,width in outputs:
                wrapper+=f'wire [{width-1}:0] {prefix}_{name};\n'
            wrapper+=module+' '+prefix+'('+','.join(f'.{name}({name})' for name in inputs)+','+','.join(f'.{name}({prefix}_{name})' for name,width in outputs)+');\n'
        wrapper+='task compare;begin\n'
        for name,width in outputs:
            wrapper+=f'if(a_{name} !== b_{name}) $fatal(1,"{name} mismatch cycle %d: %h vs %h",cycle,a_{name},b_{name});\n'
        wrapper+='''if(b_balance%5!=0) $fatal(1,"Production balance invariant failed");
end endtask
initial begin
#1;rst_n=0;#1;
'''
        wrapper+=f'for(cycle=0;cycle<{args.cycles};cycle=cycle+1) begin\n'
        wrapper+='''clk=0;
rst_n=(cycle%4093!=0);
noise=$random(seed);deal_draw_pulse=(noise&15)==0;
noise=$random(seed);hold_mask=noise;
noise=$random(seed);candidate=noise;
if(cycle%1024<64) candidate=10+(cycle%5);
noise=$random(seed);prng_ready=(noise&3)!=0;
#20;compare();
clk=1;#20;compare();
end
$display("PASS: 100000 clock cycles, all core outputs, both half phases, resets and raw controls");
$finish;
end
endmodule
'''.replace('100000 clock cycles',f'{args.cycles} clock cycles')
        bench=work/'core_equivalence.v';bench.write_text(wrapper);sources.append(bench)
        executable=work/'sim'
        subprocess.run(['iverilog','-g2012','-s','core_equivalence','-o',str(executable),*(str(p) for p in sources)],check=True)
        subprocess.run(['vvp',str(executable)],check=True)


if __name__=='__main__': main()
