# Potential area optimizations

- Earlier baseline reported by GitHub Actions: 66.265% placement utilization and 1,387 cells, excluding fill and tap cells, before VGA integration. The measured baseline for the experiments below is 68.086%.
- These are ideas to measure, not guaranteed savings.
- Keep gameplay, duplicate protection, payouts, balance limits, and production debounce timing unchanged.

## Measured results

Results reported by GitHub Actions on 2026-11-16 and reviewed through
2026-11-17, before VGA integration. Each implementation branches independently
from `989fd40`:

| Experiment | Commit | Utilization | Wire length (um) | Run |
| --- | --- | --- | --- | --- |
| Baseline | `989fd40` | 68.086% | 66,630 | [Baseline run](https://github.com/h4kyu/tapeout/actions/runs/43896181617) |
| Fixed card-slot writes | `fab934a` | 64.121% | 53,934 | [Fixed-slot run](https://github.com/h4kyu/tapeout/actions/runs/43902056794) |
| Directly indexed 64-bit used-card mask | `08788d4` | 68.870% | 67,612 | [Direct-mask run](https://github.com/h4kyu/tapeout/actions/runs/43904844459) |
| Shared rank comparisons and simplified counting | `db260f4` | 66.324% | 56,990 | [Shared-rank run](https://github.com/h4kyu/tapeout/actions/runs/43916160180) |
| Shared balance arithmetic | `956ad73` | 66.166% | 79,970 | [Shared-balance run](https://github.com/h4kyu/tapeout/actions/runs/43919449758) |
| Used-card list | `b88aa25` | 65.997% | 59,949 | [Used-card-list run](https://github.com/h4kyu/tapeout/actions/runs/43924989325) |
| Multicycle hand evaluation | `e6e9840` | 70.431% | 59,182 | [Multicycle run](https://github.com/h4kyu/tapeout/actions/runs/44128548992) |
| Derived displayed payout | `36d6d17` | 68.086% | 65,562 | [Derived-payout run](https://github.com/h4kyu/tapeout/actions/runs/44131209139) |

Final job status checked through the GitHub Actions API on 2026-11-17: all
eight linked runs (baseline and seven experiments) completed with successful
`gds`, `precheck`, `gl_test`, and `viewer` jobs. This supersedes the pending
precheck statuses in the original screenshot observations below. Numeric area
and routing results come from the recorded branch observations and supplied
screenshots; final timing/slack reports have not been reviewed. Local and remote
optimization branch tips match, and all seven share baseline `989fd40`. No
experiment changes the flow configuration relative to that baseline.

- Fixed card-slot writes reduced utilization by 3.965 percentage points (5.82% relative) and wire length by 12,696 um (19.05%).
- For fixed card-slot writes, all 14 local RTL tests passed; GDS, precheck, gate-level test, and viewer jobs passed in the reported run.
- The direct-mask experiment branched directly from `989fd40`; it did not include fixed card-slot writes. Compare it against 68.086%, not 64.121%.

### Direct-mask observation

The reported direct-mask run increased area and routing demand:

| Metric | Baseline (`989fd40`) | Direct mask (`08788d4`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 68.870% | +0.784 percentage points (+1.15% relative) |
| Wire length (um) | 66,630 | 67,612 | +982 (+1.47%) |
| Cells, excluding fill and tap | 1,462 | 1,477 | +15 |
| Flip-flops | 157 | 169 | +12 |
| Clock cells | 68 | 99 | +31 |

All 15 local RTL tests passed, including coverage of all 52 valid card codes,
all 12 invalid codes, duplicate/discard rejection, and mask clearing between
rounds and on reset. GDS, precheck, gate-level test, and viewer jobs passed in
the supplied run summary.

The 12 extra flip-flops survived synthesis. Removing the compact-index arithmetic
did not offset the resulting implementation cost in this run; clock-cell count
also increased. Treat this candidate as an area regression and leave it out of
the next experiment. Keep the added regression test available for future dealer
changes. These results do not establish a timing improvement or regression.

### Shared-rank observation

The shared-rank experiment branched directly from `989fd40`; it did not include
fixed card-slot writes or the direct mask. The evaluator expresses the ten unique
card-pair rank comparisons once and reuses them for match counting, high-pair
qualification, and duplicate-card detection with suit equality. One 4-bit total
of matching pairs replaces the per-card integer counters.

| Metric | Baseline (`989fd40`) | Shared ranks (`db260f4`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 66.324% | -1.762 percentage points (-2.59% relative) |
| Wire length (um) | 66,630 | 56,990 | -9,640 (-14.47%) |
| Cells, excluding fill and tap | 1,462 | 1,418 | -44 (-3.01%) |
| Flip-flops | 157 | 157 | Unchanged |

All 14 local RTL tests passed, including evaluator category/permutation coverage
and 3,000 random valid hands against the Python reference. A separate simulation
of 100,000 random packed 30-bit inputs matched the original evaluator's category
and payout, including invalid ranks and duplicate cards.

In the supplied run screenshot, GDS, gate-level test, and viewer jobs passed;
precheck was still running. Final precheck status and timing metrics were not
provided. The run shows an area and routing reduction, but does not establish a
timing improvement. Keep this candidate for a later combined test with fixed
card-slot writes; their individual savings may not add together.

### Shared-balance observation

The shared-balance experiment branched directly from `989fd40`; it did not
include fixed card-slot writes, the direct mask, or shared rank comparisons.
One adder handles both the five-credit wager and payout crediting by selecting
between `16'hfffb` (-5 modulo 2^16) and the zero-extended payout. Wager updates
use the low 16 bits; payout updates use the carry to saturate at 65,535.
The insufficient-credit check remains unchanged.

| Metric | Baseline (`989fd40`) | Shared balance (`956ad73`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 66.166% | -1.920 percentage points (-2.82% relative) |
| Wire length (um) | 66,630 | 79,970 | +13,340 (+20.02%) |
| Cells, excluding fill and tap | 1,462 | 1,415 | -47 (-3.21%) |
| Flip-flops | 157 | 157 | Unchanged |
| Combo logic cells | 306 | 284 | -22 |
| NAND cells | 208 | 164 | -44 |
| Multiplexer cells | 11 | 13 | +2 |
| Buffer cells | 270 | 269 | -1 |
| Clock cells | 68 | 60 | -8 |

All 15 local RTL tests passed, including new boundary coverage for balances
0 through 6 and 65,535, zero payout, exact saturation threshold, payout overflow,
and crediting only once. GDS, precheck, gate-level test, and viewer jobs passed
in the supplied run screenshot. Final timing metrics were not provided.
The existing gate-level wrapper test covers reset/status outputs, not full
gate-level gameplay; the standalone core tests exercise RTL.

This run shows an area reduction with a routing-length regression. The cell
counts describe the full implementation and do not isolate the adder's cost.
Keep this as an area-saving candidate, but compare timing and routing in any
combined experiment before selecting it. Fixed slot writes remain the strongest
measured standalone area reduction; shared ranks also reduced wire length.
Individual changes may interact when combined.

### Used-card-list observation

The used-card-list experiment branched directly from `989fd40`; it did not
include fixed card-slot writes, the direct mask, shared rank comparisons, or
shared balance arithmetic. Ten six-bit entries and a four-bit occupied count
replace the registered 52-bit mask. Candidate rejection compares against occupied
entries. The list retains discarded cards through the draw, and a fresh deal or
reset clears the count so stale entries are ignored. The existing `dealt_mask`
inspection output is derived combinationally from the list, with no second mask
register; the production wrapper leaves it unconnected.

| Metric | Baseline (`989fd40`) | Used-card list (`b88aa25`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 65.997% | -2.089 percentage points (-3.07% relative) |
| Wire length (um) | 66,630 | 59,949 | -6,681 (-10.03%) |
| Cells, excluding fill and tap | 1,462 | 1,379 | -83 (-5.68%) |
| Flip-flops | 157 | 163 | +6 |
| Combo logic cells | 306 | 271 | -35 |
| Buffer cells | 270 | 229 | -41 |
| NOR cells | 253 | 168 | -85 |
| NAND cells | 208 | 199 | -9 |
| OR cells | 122 | 162 | +40 |
| Clock cells | 68 | 90 | +22 |
| AND cells | 62 | 54 | -8 |
| Multiplexer cells | 11 | 40 | +29 |
| Inverter cells | 5 | 3 | -2 |

All 15 local RTL tests passed. The new regression fills all ten entries, rejects
every earlier accepted card before each replacement, checks the derived mask,
and reuses all ten card codes in the following round. Existing tests cover
invalid and duplicate candidates, discarded-card rejection, all 32 hold masks,
accounting, and reset during both dealing and drawing. This branch does not
include the direct-mask branch's exhaustive valid/invalid card-code regression.

GDS, precheck, gate-level test, and viewer jobs passed in the supplied run
screenshot. Final timing metrics were not provided. The existing gate-level
wrapper test checks reset/status outputs; standalone core tests exercise RTL.

The full implementation uses six more flip-flops but 83 fewer non-fill/tap
cells, with lower utilization and wire length. This supports keeping the list
as a candidate for a later combined experiment. The category counts describe
the full implementation and do not isolate the dealer's cost. They also do not
prove that every compatibility-decode gate was removed; inspect the synthesis
netlist if that needs confirmation. Fixed card-slot writes still have the best
measured standalone utilization and wire length. These results do not establish
a timing improvement, and combined savings must be measured separately.

### Multicycle-evaluator observation

The multicycle experiment branched directly from `989fd40`; it did not include
any earlier optimization. Five card-scan cycles collect validity, flush status,
rank bounds, and ace-low straight eligibility. Ten cycles compare the unordered
card pairs using shared comparison and counting hardware. A final cycle
registers the category and pulses completion. The core waits in EVALUATE and
credits the payout once on the following edge. EVALUATE lasts 17 clocks
(680 ns at 25 MHz), versus one clock at baseline.

| Metric | Baseline (`989fd40`) | Multicycle (`e6e9840`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 70.431% | +2.345 percentage points (+3.44% relative) |
| Wire length (um) | 66,630 | 59,182 | -7,448 (-11.18%) |
| Cells, excluding fill and tap | 1,462 | 1,458 | -4 (-0.27%) |
| Flip-flops | 157 | 188 | +31 |
| Combo logic cells | 306 | 329 | +23 |
| Buffer cells | 270 | 267 | -3 |
| NOR cells | 253 | 181 | -72 |
| NAND cells | 208 | 189 | -19 |
| OR cells | 122 | 101 | -21 |
| Clock cells | 68 | 138 | +70 |
| AND cells | 62 | 41 | -21 |
| Multiplexer cells | 11 | 19 | +8 |
| Inverter cells | 5 | 5 | Unchanged |

All 16 local RTL tests passed. Coverage includes all categories and straight
windows with card permutations, 3,000 random valid hands, 1,000 random raw card
encodings, completion latency, busy-start rejection, reset cancellation,
core waiting, and exactly-once payout crediting. Verilator lint passed with
existing wrapper filename and intentionally unconnected-pin warnings excluded.

In the supplied screenshot, GDS, gate-level test, and viewer jobs passed;
precheck was still running. Final precheck status and timing metrics were not
provided. The gate-level wrapper test checks reset/status outputs; standalone
core and evaluator tests exercise RTL.

This implementation regressed utilization despite shorter routing and four
fewer non-fill/tap cells. Cell counts are not weighted by cell area. The added
31 flip-flops and 70 clock cells suggest that sequential control and clocking
cost outweighed the removed parallel logic; these full-design counts do not
isolate the evaluator's area. Shorter wire length does not establish a timing
improvement. Exclude this implementation from the area-saving combination;
preserve the branch as the measured experiment. This result applies to this
implementation, not every possible multicycle evaluator.

### Derived-payout observation

The derived-payout experiment branched directly from `989fd40`; it includes no
other optimization. The core retains the final four-bit category and derives
`result_payout` through a combinational fixed-award lookup instead of latching
another 12-bit result. The evaluator payout and balance-crediting path are
unchanged. Category zero produces zero payout on reset and a new accepted deal.

| Metric | Baseline (`989fd40`) | Derived payout (`36d6d17`) | Change |
| --- | --- | --- | --- |
| Utilization | 68.086% | 68.086% | Unchanged at reported precision |
| Wire length (um) | 66,630 | 65,562 | -1,068 (-1.60%) |
| Cells, excluding fill and tap | 1,462 | 1,452 | -10 (-0.68%) |
| Flip-flops | 157 | 157 | Unchanged |
| Combo logic cells | 306 | 306 | Unchanged |
| Buffer cells | 270 | 260 | -10 |
| Clock cells | 68 | 67 | -1 |
| Inverter cells | 5 | 6 | +1 |
| Fill cells | 994 | 1,027 | +33 (excluded from cell total above) |

NOR, NAND, OR, AND, and multiplexer counts also remained unchanged. The net
non-fill/tap cell reduction is accounted for by ten fewer buffers, one fewer
clock cell, and one more inverter. The unchanged flip-flop and logic counts are
consistent with unused payout storage already being pruned in the baseline;
this is an inference from the counts, not a confirmed netlist comparison.
Placement/routing variation may explain the buffer and wire-length changes;
a single run does not establish them as repeatable savings from this change.
Record this as neutral utilization, with no demonstrated payout-register saving
in the current top level.

All 15 local RTL tests passed, including all ten final category/payout values,
stability in RESULT, clearing on a fresh deal, asynchronous reset, and existing
accounting/overflow tests. The supplied screenshot showed precheck and gate-level
tests in progress; the final API check confirms all four workflow jobs passed.
Final timing/slack has not been reviewed. Keep the implementation as a small,
compatible cleanup, but measure it again when VGA consumes `result_payout`.

## Consolidation recommendation

Use **one integration branch with separate implementation commits and staged
measurements**, then submit the selected combination as one PR. Preserve the
standalone experiment branches and their run links. Do not squash the work into
one opaque implementation change or merge every experimental branch into main.
Whole-branch merges would also import overlapping copies of this observations
file and stale next-step recommendations.

Suggested starting point: `opt/combined-area` from `989fd40` (or a newer main
only after establishing its own baseline). This review does not create that
branch or merge any RTL changes.

| Stage | Changes | Compare against | Purpose |
| --- | --- | --- | --- |
| A | Fixed slot writes (`fab934a`) + shared ranks (`db260f4`) | Baseline and fixed-slot standalone run | Combine two independent, low-latency changes with area and routing wins |
| B | Stage A + used-card list (`b88aa25`) | Stage A | Check the list's incremental saving with fixed writes already present |
| C, optional | Best of A/B + shared balance arithmetic (`956ad73`) | That same A/B version | Decide whether the extra area saving justifies routing and timing effects |
| D, cleanup | Selected version + derived payout (`36d6d17`) | Selected version without it | Keep payout behavior coverage; do not assume current area savings |

Keep each implementation in its own commit, with its relevant tests. Stage B
is especially important: fixed writes and the list are logically compatible,
but both change the dealer, and their independently measured savings may not
add. A combined implementation can map differently in synthesis and routing.
Stage C must be a separate comparison because shared balance arithmetic grew
standalone wire length by 20.02%. Shorter or longer aggregate wire length alone
does not determine timing closure.

The immediate experiment should be **Stage A**, then Stage B. If build budget
only permits one initial combined GDS run, test Stage B directly; if its result
is disappointing, measure Stage A to isolate the list's contribution. Do not
predict combined utilization by summing percentage-point reductions.

For delivery, one PR with separate commits provides a concrete tested combined
state and easy per-change review. Individual PRs are also reasonable for team
coordination, starting with fixed slot writes, but rebase and rerun the full
checks after each merge: standalone baseline results do not validate the new
cumulative main. Avoid merging several independently tested branches and then
assuming the aggregate is validated.

## Compatibility and exclusions

| Changes | Relationship | Integration action |
| --- | --- | --- |
| Compact 52-bit mask / direct 64-bit mask / used-card list | Alternative duplicate-history representations | Select exactly one; use the list only if Stage B wins. Exclude the direct mask, which regressed utilization |
| Shared rank comparisons / multicycle evaluator | Alternative evaluator implementations in the measured branches | Keep the combinational shared-rank evaluator. The multicycle branch replaces it, changes ports/tests, and adds completion control; exclude its area regression |
| Fixed slot writes + used-card list | Compatible behavior; overlapping source edits | Preserve the five fixed hand slices while retaining list insertion, count limit, duplicate checks, and discard lifetime |
| Shared balance + derived payout | Compatible; edits touch nearby sequential assignments | Preserve the shared adder and saturation while removing every sequential assignment to `result_payout`; retain its combinational lookup |
| Dealer changes + shared ranks | Separate modules; compatible interfaces | Retain cards encoding, compact `dealt_mask` inspection output, and existing state timing |
| Multicycle evaluator + balance/payout changes | Not inherently exclusive, but needs controller/test adaptation | Do not include in this area combination. A future revisit must preserve the completion handshake and exactly-once crediting |

A textual conflict is not necessarily an architectural conflict. Conversely,
a clean merge does not show that both optimizations survived: inspect the final
dealer to ensure a merge did not restore variable hand writes or the old mask.
The list has its own variable-index history-entry write; fixed hand-slot writes
do not remove or optimize that separate storage path.

Read-only three-way merge checks against `989fd40` found a source conflict in
each of fixed slots + used list, shared ranks + multicycle, and shared balance +
derived payout. The first and third require manual integration of compatible
changes; the second needs an explicit evaluator architecture choice. These
checks used temporary files and did not merge any branch or validate combined RTL.

Cherry-pick the implementation commits, not the later documentation-only
observation commits. Resolve this file once as the consolidated record. Carry
over the list's ten-card rejection/reuse regression and, independently of the
rejected direct-mask implementation, its exhaustive all-card-code regression.
Keep balance boundary tests whenever testing the shared adder. Import each
Cocotb test into `test/test.py` so the standard suite actually discovers it.

Run the full RTL suite for each stage and the same GDS/precheck/gate-level flow
for each measured revision. Record the exact commit, utilization, non-fill/tap
cell count, wire length, final setup/hold slack at 25 MHz, and all job outcomes.
The current gate-level wrapper test covers reset/status; the standalone gameplay
and evaluator tests remain RTL, so a green `gl_test` is not full gate-level
gameplay coverage. Preserve all hold masks, duplicate/discard protection,
invalid-code rejection, new-round clearing, reset, payouts, bankruptcy,
saturation, and exactly-once crediting.

Repeat the selected comparison with the real VGA integration, where previously
unused outputs may be retained. The existing `luke/vga-shell-integration` branch
also adds `keep` attributes to renderer-facing state; treat that as a different
measurement configuration and establish a fresh baseline there. In particular,
derived payout may matter once retained, and the list's synthesized cost can
change if anything starts consuming its reconstructed `dealt_mask` output.

## Candidates

- **Fixed card-slot writes — `poker_dealer.v`**
  - Replace the variable card slice with five fixed slices selected by `slot`.
  - May simplify the logic that routes a candidate into a hand slot.
  - Small first experiment; synthesis may already build the same circuit.

- **Directly indexed used-card mask — `poker_dealer.v`**
  - Try a 64-bit mask indexed directly by the six-bit card code.
  - Removes the current `suit * 13 + rank - 2` index calculation.
  - Costs 12 extra stored bits; measure whether the total circuit gets smaller.
  - Keep invalid-rank rejection and account for the existing 52-bit mask interface and tests.

- **Used-card list instead of a mask — `poker_dealer.v`**
  - Store up to 10 used cards and compare candidates against that list.
  - An alternative to either mask design, not an extra optimization to stack on top.
  - Needs up to 60 card-storage bits, a count, and comparisons; could be larger.

- **Shared rank comparisons — `poker_evaluator.v`**
  - Express the 10 unique card-pair comparisons once and reuse their results.
  - Avoid repeated comparisons and simplify hand counting where possible.
  - Synthesis may already remove duplicate work.

- **Multicycle hand evaluation — `poker_evaluator.v`, `poker_core.v`**
  - Reuse comparison and counting hardware over several clock cycles.
  - Could save area at the cost of extra control logic and a small evaluation delay.
  - Requires the core to wait for evaluation completion; more involved than the other changes.

- **Derive displayed payout from category — `poker_core.v`**
  - Store the final category and calculate its fixed payout instead of storing another 12-bit result.
  - Trades payout registers for lookup logic; measure the net saving.
  - Current unused payout storage may already be removed by synthesis; revisit when VGA uses it.

- **Shared balance arithmetic — `poker_core.v`**
  - Try sharing arithmetic hardware for wager subtraction and payout addition.
  - These operations happen at different times.
  - Preserve insufficient-credit checks and saturation; selection logic may offset savings.

## How to compare experiments

- Save the baseline commit, build configuration, utilization, cell area/count, and final timing results.
- Implement one candidate at a time and run the relevant RTL tests.
- Use synthesis for an early comparison; use the full GDS flow to check placement, routing, and final timing.
- Keep the tile size, clock constraints, tool versions, and other settings the same between comparisons.
- A separate branch from the baseline for each candidate gives the clearest independent comparison.
- Alternatively, test candidates sequentially, recording a before/after result for each change.
- Combine promising changes and rerun the checks; individual savings may not add together.
- Repeat the baseline and final comparison with VGA connected, since it can retain logic currently optimized away.
- The standalone sweep is complete. Fixed card-slot writes, shared rank comparisons, shared balance arithmetic, and the used-card list reduced reported utilization. Direct masking and this multicycle implementation regressed it; derived displayed payout was neutral. Follow the staged consolidation plan above and review timing separately.
