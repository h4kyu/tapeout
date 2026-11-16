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

## Suggested next experiment

Try **shared balance arithmetic in `poker_core.v`** on a fresh branch from the
common baseline:

```sh
git switch -c opt/shared-balance-arithmetic 989fd40
```

Wager subtraction and payout addition occur in different controller states.
Express them using one 17-bit arithmetic path with a selected operand, retaining
the carry bit needed for payout saturation. Preserve the insufficient-credit
check, five-credit wager, one payout per round, reset behavior, and saturation at
65,535. This candidate adds no stored state or evaluation latency; the operand
selection logic may offset any arithmetic savings.

Run the complete RTL suite, especially bankruptcy, overflow, reset, and complete
round accounting, then the same GDS flow. Compare independently against
`989fd40`: 68.086% utilization, 66,630 um wire length, and 1,462 non-fill/tap cells.
Keep the dealer and evaluator at baseline for this test. Record final precheck,
gate-level, and timing results before deciding whether to combine candidates.

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
- Fixed card-slot writes and shared rank comparisons have measured savings. Test shared balance arithmetic independently next; consider multicycle evaluation if a larger saving is needed.
