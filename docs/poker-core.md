# Poker game core

see `proposal/SystemDiagram.excalidraw` for system diagram.

implements the following modules:
- `poker_dealer.v`: five hand-slot banks, an original-hand snapshot, initial deal, and selective replacement.
- `poker_evaluator.v`: combinational hand classification with shared rank comparisons and a fixed-wager pay table.
- `poker_core.v`: round control, wager deduction, result latching, and balance.

## Card representation

Each card is `{suit[1:0], rank[3:0]}`, with ranks 2 through 14 (ace). Rank codes 0, 1, and 15 are rejected. 
Suit codes 0 through 3 are distinct suits.

`cards[5:0]` is card 1, through `cards[29:24]` card 5.
`hold_mask[0]` controls card 1. This experiment represents the round's used
cards as the union of its original hand and current hand. During initial dealing,
the current hand alone contains all accepted cards. A start-draw snapshot keeps
discarded cards in the set while replacements enter the current hand. The core
permits one initial deal and at most one draw per round; a new deal invalidates
the snapshot and clears current cards. Invalid ranks and duplicate candidates
remain rejected, with unchanged transfer timing.
`dealt_mask` is a combinational inspection view with row-major index
`13 * suit + rank - 2`, not a second stored history. It is unused by the wrapper.

Zeroed card registers before a deal are not valid cards.

## Core interface contract

All transfers occur on the rising edge of the system clock. Reset is active-low and asynchronous. 

| Signal | Direction at core | Meaning |
| --- | --- | --- |
| `deal_draw_pulse` | Input | One-clock event from the debounced deal/draw button |
| `hold_mask[4:0]` | Input | Synchronized hold switches, captured when drawing starts |
| `candidate[5:0]` | Input | Candidate card from PRNG adapter |
| `prng_ready` | Input | PRNG candidate is available on this edge |
| `dealer_ready` | Output | Dealer can consume a candidate on this edge |
| `cards[29:0]` | Output | Five packed hand registers |
| `dealt_mask[51:0]` | Output | All cards accepted in this round, including discards |
| `held_cards[4:0]` | Output | Hold indicators: track switches in HOLD, frozen during draw/result |
| `state[2:0]` | Output | State codes below |
| `balance[15:0]` | Output | Current credit balance |
| `hand_category[3:0]` | Output | Live classification of the current cards; display when the hand is complete |
| `result_category[3:0]` | Output | Final hand category, valid in RESULT |
| `result_payout[11:0]` | Output | Final award, valid in RESULT |
| `can_deal` | Output | Idle/result state with at least five credits |

Transfer is `prng_ready && dealer_ready`. The producer must advance after every transfer.
An adapter can assert `prng_ready` continuously and advance the LFSR on `dealer_ready`. A free-running LFSR can also provide a candidate each cycle.

`deal_draw_pulse` starts a deal or draw. Hold/unhold uses the independent `hold_mask` levels and cannot start either operation. 
Pulses while busy are ignored, not queued. The final input adapter must produce one pulse per debounced press and require a debounced release before rearming, we avoid connecting `button_out` directly to `deal_draw_pulse`.

The dealer samples `start`, `draw_mode` and the hold mask together when idle.
The evaluator is combinational, so the controller's EVALUATE state supplies a full cycle for it to settle.
`hand_category` exposes this same evaluator for the live VGA message; it does not
instantiate another evaluator. The standalone evaluator validates arbitrary
card codes; the core instance uses the dealer's valid/unique-hand guarantee.
Partial initial hands still report zero until the final card is present.
`result_category` still latches the final award.

## Round and accounting rules

| State | Code | Transition |
| --- | --- | --- |
| IDLE | 0 | Accepted action deducts five credits and starts DEALING |
| DEALING | 1 | Dealer completion advances to HOLD |
| HOLD | 2 | Action captures holds and starts DRAWING |
| DRAWING | 3 | Dealer completion advances to EVALUATE |
| EVALUATE | 4 | Latch classification, credit award once, advance to RESULT |
| RESULT | 5 | Preserve final hand/award until the next affordable deal |

Reset restores 100 credits and clears all hand, deck and result state. Initial dealing ignores hold switches. Hold-all draws complete without consuming any candidate. Each new deal clears the previous result and used-card history.

The core stores only the final category and derives `result_payout` from it
with a combinational fixed-award lookup, avoiding a separate 12-bit payout
register. Balance crediting still uses the evaluator's payout in EVALUATE.

The award is added after the wager has already been deducted. Balance saturates at 65,535 instead of wrapping. Below five credits, new-deal actions do nothing, reset starts a new session. Behavior can be adjusted independently of the dealer later.

| Category | Code | Award |
| --- | --- | --- |
| No qualifying hand | 0 | 0 |
| Jacks or better | 1 | 5 |
| Two pair | 2 | 10 |
| Three of a kind | 3 | 15 |
| Straight | 4 | 20 |
| Flush | 5 | 30 |
| Full house | 6 | 45 |
| Four of a kind | 7 | 125 |
| Straight flush | 8 | 250 |
| Royal flush | 9 | 4000 |

Ace is high except in A-2-3-4-5. Category precedence selects the strongest applicable hand.

## Integration and validation

`project.v` now connects `poker_inputs`, the free-running PRNG, and `poker_core`.
Hold switches pass through two synchronization registers. The button passes
through the existing debounce filter and rising-edge detection, generating one
action per accepted press. The wrapper's `DEBOUNCE_CYCLES` parameter defaults
to 500,000 (20 ms at 25 MHz); RTL integration tests override it to five.

`project.v` connects the game-state wires to the active `vga` renderer and maps
its RGB/sync outputs to the documented VGA pins. The current renderer generates
640×480 video with card faces, HOLD labels, hand names, and a
native-size credits/BET/result footer. The core's existing evaluator supplies
the live category; no extra evaluator is instantiated. Game-state signals remain
available as named wrapper wires for RTL simulation.

The terminal simulator derives deal availability from the exposed state and
balance: state IDLE or RESULT, with at least five credits. It does not require a
wrapper-level `can_deal` wire.

Run `make` in `test/` with the pinned Python dependencies and Icarus Verilog installed. The shared testbench contains standalone core and evaluator instances, and `test.py` imports the core tests alongside the wrapper and debounce tests. GitHub's existing RTL test workflow runs the combined suite and reports results in `results.xml`. The 22-test chip suite includes every category and straight window, permutations, 3,000 random valid hands, 1,000 raw encoded hands, all 32 hold masks, every valid/invalid card code, ten-card rejection and reuse, balance boundaries, displayed payouts, accounting and reset, plus font and VGA component coverage.

See [the staged area results](combined-area-results.md) for the upstream core
and retained-output-shell routing/timing measurements, including remaining
slow-corner setup violations. Those results do not establish fit or timing for
the complete active renderer. The gate-level job checks defined wrapper outputs
across reset; standalone gameplay tests still use RTL in that job.

## Experimental storage and synthesis

This branch uses GF180 integrated clock gates and a stable-input latch bank.
Logical transfers, asynchronous reset values, state codes, and 16-bit accounting
are unchanged. The converter's production units-digit storage relies on the
invariant that reset, wagers, awards, and saturation produce multiples of five.
See [the area experiment](vga-area-experiment.md) for the exact implementation,
reference checks, measurement recipe, and remaining physical/timing work.
