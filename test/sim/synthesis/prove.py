"""Compare pure rendering/evaluation logic to a Git baseline with Yosys SAT.

Run from test/: python3 -m sim.synthesis.prove --reference 5b52905
Footer proof covers address logic with valid BCD digits; conversion/storage is
checked separately by tb_credits_exhaustive.v. This is not sequential signoff.
"""
from pathlib import Path
import subprocess,re
import argparse, shutil, tempfile
parser=argparse.ArgumentParser(description='SAT-check combinational behavior against the reviewed renderer baseline')
parser.add_argument('--reference',default='5b52905')
parser.add_argument('--reference-dir',type=Path,help='Optional exported baseline tree')
parser.add_argument('--output',type=Path,default=Path('output/equivalence'))
args=parser.parse_args()
if not shutil.which('yosys'):
 parser.error('yosys is required')
root=Path(__file__).resolve().parents[3]
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
workspace=tempfile.TemporaryDirectory(prefix='vga-equivalence-')
specs=[('card_faces',[('x',10),('y',10),('cards',30)],[('active',1),('text_active',1),('character',6),('glyph_x',4),('glyph_y',4),('red_suit',1)]),('hold_labels',[('x',10),('y',10),('held_cards',5)],[('text_active',1),('character',6),('glyph_x',4),('glyph_y',4)]),('hand_message',[('x',10),('y',10),('state',3),('hand_category',4),('result_category',4)],[('text_active',1),('yellow',1),('text_row',4),('text_column',4),('glyph_x',4),('glyph_y',4),('pixel_x',5),('pixel_y',5)]),('font_rom',[('character',6),('row',4)],[('pixels',12)]),('poker_evaluator',[('cards',30)],[('category',4),('payout',12)]),('credits_bet',[('x',10),('y',10),('state',3),('payout',12),('balance',16),('clk',1),('rst_n',1),('displayed_digits',20)],[('text_active',1),('character',6),('glyph_x',4),('glyph_y',4),('pixel_x',5),('pixel_y',5)])]
for name,ins,outs in specs:
 old=(args.reference_dir/'src'/f'{name}.v').read_text() if args.reference_dir else subprocess.check_output(['git','show',f'{args.reference}:src/{name}.v'],cwd=root).decode()
 new=(root/f'src/{name}.v').read_text()
 if name=='credits_bet':
  for which,text in [('old',old),('new',new)]:
   start=text.index('    // Serial double-dabble');end=text.index('    function [5:0] credits_character') if which=='old' else text.index('    wire [19:0] digits =')
   text=text[:start]+text[end:]
   loc=text.index('    input wire [2:0] state,');text=text[:loc]+'    input wire [19:0] displayed_digits,\n'+text[loc:]
   if which=='old':old=text
   else:new=text
 old=re.sub(r'\bmodule\s+'+name+r'\b','module gold_'+name,old,count=1)
 decl=lambda k,w: f'{"["+str(w-1)+":0] " if w>1 else ""}{k}'
 wrap='module miter('+','.join('input wire '+decl(k,w) for k,w in ins)+',output wire ok);\n'
 for p in ['a','b']:
  wrap+='\n'.join('wire '+decl(p+'_'+k,w)+';' for k,w in outs)+'\n'
  wrap+=(('gold_'+name) if p=='a' else name)+' '+p+'('+','.join('.'+k+'('+k+')' for k,w in ins)+','+','.join('.'+k+'('+p+'_'+k+')' for k,w in outs)+');\n'
 comparisons=[]
 for k,w in outs:
  test=f'(a_{k}==b_{k})'
  if name in ['card_faces','hold_labels','credits_bet'] and k not in ['active','text_active']:
   test='(!a_text_active || '+test+')'
  comparisons.append(test)
 if any(k=='glyph_x' for k,w in outs):
  comparisons+=['(!a_text_active || (b_glyph_x<12 && b_glyph_y<12))']
 if name=='credits_bet':
  valid=' && '.join(f'(displayed_digits[{i*4} +:4]<=9)' for i in range(5))
  wrap+='assign ok= !('+valid+') || ('+' && '.join(comparisons)+');\n'
 else:wrap+='assign ok='+' && '.join(comparisons)+';\n'
 wrap+='endmodule\n'
 files={'gold.v':old,'new.v':new,'miter.v':wrap}
 if name=='hold_labels':files['deps.v']=(root/'src/card_faces.v').read_text()
 target=Path(workspace.name)/name;target.mkdir()
 for filename,content in files.items():(target/filename).write_text(content)
 command='read_verilog -sv *.v; hierarchy -top miter; proc; flatten; opt; memory_map; opt; sat -verify -prove ok 1 -set-def-inputs -show-inputs'
 result=subprocess.run(['yosys','-Q','-T','-p',command],cwd=target,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/('proof-'+name+'.log')).write_bytes(result.stdout)
 print(name,'PASS' if result.returncode==0 else 'FAIL',flush=True)
 if result.returncode:
  raise SystemExit(f'See {out/("proof-"+name+".log")}')
 if name=='poker_evaluator':
  # The production instance omits validation only under the dealer guarantee.
  legal=' && '.join(f'(cards[{i*6} +:4]>=2 && cards[{i*6} +:4]<=14)' for i in range(5))
  legal+=' && '+' && '.join(f'(cards[{i*6} +:6]!=cards[{j*6} +:6])' for i in range(5) for j in range(i+1,5))
  specialized=wrap.replace('poker_evaluator b(', 'poker_evaluator #(.DEALER_VALIDATED(1)) b(')
  specialized=specialized.replace('assign ok=', 'assign ok= !('+legal+') || ')
  (target/'miter.v').write_text(specialized)
  result=subprocess.run(['yosys','-Q','-T','-p',command],cwd=target,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  (out/'proof-dealer-validated-evaluator.log').write_bytes(result.stdout)
  print('dealer_validated_evaluator','PASS' if result.returncode==0 else 'FAIL',flush=True)
  if result.returncode: raise SystemExit('Dealer-validated evaluator proof failed')
workspace.cleanup()
