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

## Suggested next experiment

**Derive displayed payout from the registered category in `poker_core.v`** is
the final untested standalone candidate on the original list. Suggested branch:

```sh
git switch -c opt/derived-payout 989fd40
```

Replace the 12-bit `result_payout` register with a combinational decode of
`result_category`, using the existing fixed-wager pay table. Category zero must
decode to zero so reset, initial deal, HOLD, DRAWING, and EVALUATE still expose
zero result payout. Preserve the core interface and the registered category.
Keep the evaluator's current-hand payout path and balance crediting unchanged;
this experiment concerns the displayed result only. Preserve category/payout
stability in RESULT and clear the result on the next accepted deal.

The baseline wrapper leaves `result_payout` unused, so synthesis may already
remove its storage and decode. This candidate may therefore produce no area
benefit in the current build. Confirm that in the synthesis reports or netlist;
repeat the comparison when VGA actually consumes the output. Do not change the
production output mapping merely to retain it for this experiment.

Keep dealer logic, the combinational evaluator, balance arithmetic, input
handling, and flow configuration at `989fd40`. Run the complete baseline RTL
suite and verify the displayed payout for every category, result clearing,
reset, and exactly-once accounting. Compare the same GDS flow against 68.086%
utilization, 66,630 um wire length, and 1,462 non-fill/tap cells, recording final
job statuses and timing. Suggested branch only; no branch switch or payout
implementation is included in this observations update.

After the standalone sweep, start `opt/combined-area` from `989fd40` and combine
fixed card-slot writes (`fab934a`), shared rank comparisons (`db260f4`), and the
used-card list (`b88aa25`). Resolve their overlapping edits in the dealer while
preserving fixed slot writes and the list's duplicate/discard protection. Keep
the evaluator combinational. Measure the combination before adding shared
balance arithmetic (`956ad73`) as a separate follow-up, since its standalone
wire length increased by 20.02%. Exclude the direct mask and multicycle evaluator.
Combined savings cannot be inferred by adding the standalone reductions.

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
- Fixed card-slot writes, shared rank comparisons, shared balance arithmetic, and the used-card list have measured area savings. Direct masking and this multicycle implementation regressed utilization. Derived displayed payout is the last standalone candidate; then measure combinations of the successful changes, checking timing and routing separately.
