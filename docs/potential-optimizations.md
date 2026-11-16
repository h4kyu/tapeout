# Potential area optimizations

- Earlier baseline reported by GitHub Actions: 66.265% placement utilization and 1,387 cells, excluding fill and tap cells, before VGA integration. The measured baseline for the experiments below is 68.086%.
- These are ideas to measure, not guaranteed savings.
- Keep gameplay, duplicate protection, payouts, balance limits, and production debounce timing unchanged.

## Measured results

Results reported by GitHub Actions on 2026-11-16, before VGA integration:

| Experiment | Commit | Utilization | Wire length (um) | Run |
| --- | --- | --- | --- | --- |
| Baseline | `989fd40` | 68.086% | 66,630 | [Baseline run](https://github.com/h4kyu/tapeout/actions/runs/43896181617) |
| Fixed card-slot writes | `fab934a` | 64.121% | 53,934 | [Fixed-slot run](https://github.com/h4kyu/tapeout/actions/runs/43902056794) |
| Directly indexed 64-bit used-card mask | `08788d4` | 68.870% | 67,612 | [Direct-mask run](https://github.com/h4kyu/tapeout/actions/runs/43904844459) |
| Shared rank comparisons and simplified counting | `db260f4` | 66.324% | 56,990 | [Shared-rank run](https://github.com/h4kyu/tapeout/actions/runs/43916160180) |
| Shared balance arithmetic | `956ad73` | 66.166% | 79,970 | [Shared-balance run](https://github.com/h4kyu/tapeout/actions/runs/43919449758) |

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

## Suggested next experiment

Try **a used-card list instead of a mask in `poker_dealer.v`** on a fresh branch
from the common baseline:

```sh
git switch -c opt/used-card-list 989fd40
```

Store up to ten accepted six-bit card codes and compare each candidate against
occupied entries. Clear the occupied count at the start of an initial deal and
retain every accepted card through the draw, including discarded cards. Keep
invalid-rank rejection, hold behavior, candidate acceptance timing, reset, and
round completion unchanged. Unused entries must not affect duplicate rejection.

Preserve the existing 52-bit `dealt_mask` interface by deriving it from occupied
list entries, rather than retaining a second registered mask. The production
wrapper leaves this output unconnected, so confirm synthesis removes that
compatibility logic there. Tests must still see the same compact mask values.

The hypothesis is that ten parallel equality comparisons and a small append
control can cost less than the compact-index arithmetic, variable mask read,
and variable bit write. Up to 60 stored card bits plus a count exceed the
baseline's 52 mask bits, so savings are uncertain. The direct-mask experiment
already showed that extra storage can outweigh simpler indexing.

Run the complete RTL suite, with explicit coverage of all valid/invalid card
codes, duplicates in every occupied list position, discarded-card rejection,
ten accepted cards, all hold masks, consecutive rounds, and reset. Reuse the
direct-mask branch's card-code regression coverage where applicable without
bringing in its implementation. Then run the same GDS flow and compare against
`989fd40`: 68.086% utilization, 66,630 um wire length, and 1,462 non-fill/tap cells.
Keep the evaluator and balance arithmetic at baseline for this independent test.
Record timing and final job statuses alongside area and routing results.

Defer deriving displayed payout from category until VGA consumes the result;
its currently unused storage may already be eliminated. Multicycle evaluation
remains a larger follow-up with additional control and evaluation latency.

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
- Fixed card-slot writes, shared rank comparisons, and shared balance arithmetic have measured area savings. Shared balance increased wire length. Test the used-card list independently next; combine promising candidates only in a later measured experiment.
