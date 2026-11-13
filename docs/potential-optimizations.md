# Potential area optimizations

- Baseline reported by GitHub Actions: 66.265% placement utilization and 1,387 cells, excluding fill and tap cells, before VGA integration.
- These are ideas to measure, not guaranteed savings.
- Keep gameplay, duplicate protection, payouts, balance limits, and production debounce timing unchanged.

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
- Start with fixed card-slot writes. Consider multicycle evaluation if a larger saving is needed.
