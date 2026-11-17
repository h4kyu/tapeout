# Poker area optimization decisions

The standalone experiments began at `989fd40`: 68.086% placement utilization,
66,630 µm routed wire length, and 1,462 functional cells. Their independent
results and compatibility review remain in the
[standalone observations](https://github.com/h4kyu/tapeout/blob/opt/derived-payout/docs/potential-optimizations.md).

The consolidation keeps separate implementation commits and measures each
cumulative revision. See [the complete staged results](combined-area-results.md)
and [machine-readable measurements](measurements/combined-area.json), including
exact revisions, final CI outcomes, and extracted setup/hold slack at 25 MHz.
Standalone savings do not add directly: combining fixed writes and shared ranks
increased wire length, while adding the used-card list reduced it substantially.

| Candidate | Consolidation decision |
| --- | --- |
| Fixed card-slot writes (`fab934a`) | Retain five fixed hand slices |
| Shared rank comparisons (`db260f4`) | Retain the combinational evaluator and one-cycle EVALUATE state |
| Used-card list (`b88aa25`) | Retain after incremental area, routing, and setup-slack improvement over Stage A |
| Shared balance arithmetic (`956ad73`) | Exclude from this branch: only four fewer cells, with longer routing and worse setup slack than Stage B; keep its boundary tests |
| Derived displayed payout (`36d6d17`) | Retain as the requested separate cleanup; it regresses the current wrapper versus Stage B but saves area when VGA-facing outputs are retained; see both measured comparisons |
| Direct 64-bit card mask (`08788d4`) | Exclude the area regression; retain exhaustive valid/invalid card-code tests independently |
| Multicycle evaluator (`e6e9840`) | Exclude the architecture and area regression; adapt useful straight-window and raw-code reference tests independently |

The list and masks are alternative storage representations. The selected dealer
keeps fixed hand writes, inserts accepted cards into the ten-entry list, rejects
invalid/duplicate/discarded cards, and clears list occupancy on reset/new round.
Its 52-bit inspection mask is derived combinationally and remains unconnected
in the production wrapper. Balance eligibility, saturation, exactly-once payout,
and the production debounce interval are preserved.

Measurements also repeat the comparisons using `9451a78`'s inactive VGA shell
and retained display-facing outputs on isolated measurement branches. This is a
separate configuration with its own baseline. Repeat again when the actual
renderer consumes the outputs, particularly if anything consumes `dealt_mask`.
A green GDS/precheck/gate-level workflow does not imply all-corner timing closure;
see the measured slow-corner setup violations in the staged results.
