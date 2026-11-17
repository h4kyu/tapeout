# Poker game core

see `proposal/SystemDiagram.excalidraw` for system diagram.

implements the following modules:
- `poker_dealer.v`: five hand registers, the 52-bit used-card mask, initial deal, and selective replacement.
- `poker_evaluator.v`: multicycle hand classification and fixed-wager pay table.
- `poker_core.v`: round control, wager deduction, result latching, and balance.

## Card representation

Each card is `{suit[1:0], rank[3:0]}`, with ranks 2 through 14 (ace). Rank codes 0, 1, and 15 are rejected. 
Suit codes 0 through 3 are distinct suits.

`cards[5:0]` is card 1, through `cards[29:24]` card 5.
`hold_mask[0]` controls card 1. The mask index is row-major `13 * suit + rank - 2`.
The used-card mask is cleared only on reset or the start of a new round. 

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
| `result_category[3:0]` | Output | Final hand category, valid in RESULT |
| `result_payout[11:0]` | Output | Final award, valid in RESULT |
| `can_deal` | Output | Idle/result state with at least five credits |

Transfer is `prng_ready && dealer_ready`. The producer must advance after every transfer.
An adapter can assert `prng_ready` continuously and advance the LFSR on `dealer_ready`. A free-running LFSR can also provide a candidate each cycle.

`deal_draw_pulse` starts a deal or draw. Hold/unhold uses the independent `hold_mask` levels and cannot start either operation. 
Pulses while busy are ignored, not queued. The final input adapter must produce one pulse per debounced press and require a debounced release before rearming, we avoid connecting `button_out` directly to `deal_draw_pulse`.

The dealer samples `start`, `draw_mode` and the hold mask together when idle.
The evaluator accepts `start` on the same edge that dealer completion advances
the core from DRAWING to EVALUATE. It scans one card per cycle for five cycles,
then compares one unordered card pair per cycle for ten cycles, sharing the
rank comparator and pair counter. Rank bounds and a wheel flag replace the
parallel straight-pattern checks. A final cycle registers the category and
asserts `done` for one clock; payout is decoded from the registered category.

The evaluator requires `cards` to stay stable from the accepted start through
completion; the core's dealer registers provide this without another hand copy.
Starts while evaluating are ignored. Category and payout retain the previous
result until completion, and reset clears them and cancels an active evaluation.
`done` asserts 16 clocks after start; the core latches the result and credits the
award on the following edge. EVALUATE therefore lasts 17 clocks (680 ns at
25 MHz), with input pulses ignored throughout.

## Round and accounting rules

| State | Code | Transition |
| --- | --- | --- |
| IDLE | 0 | Accepted action deducts five credits and starts DEALING |
| DEALING | 1 | Dealer completion advances to HOLD |
| HOLD | 2 | Action captures holds and starts DRAWING |
| DRAWING | 3 | Dealer completion advances to EVALUATE |
| EVALUATE | 4 | Wait for evaluator completion, latch classification, credit award once, advance to RESULT |
| RESULT | 5 | Preserve final hand/award until the next affordable deal |

Reset restores 100 credits and clears all hand, deck and result state. Initial dealing ignores hold switches. Hold-all draws complete without consuming any candidate. Each new deal clears the previous result and used-card mask.

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

Until VGA is connected, output pins expose the temporary status byte
`{1'b0, state[2:0], result_category[3:0]}`. This mapping replaces the previous
PRNG debug outputs and is not the final VGA pinout. Renderer-facing state is
available as named wrapper wires. Area measurements before renderer integration
are provisional because unused display-only logic may be optimized away.

The terminal simulator derives deal availability from the exposed state and
balance: state IDLE or RESULT, with at least five credits. It does not require a
wrapper-level `can_deal` wire.

Run `make` in `test/` with the pinned Python dependencies and Icarus Verilog installed. The shared testbench contains standalone core and evaluator instances, and `test.py` imports the core tests alongside the wrapper and debounce tests. GitHub's existing RTL test workflow runs the combined suite and reports results in `results.xml`. The core suite includes a basic deal/draw round, hold-switch independence, every hand category, every straight window, 3,000 random valid hands, 1,000 random raw encodings, all 32 hold masks, invalid/duplicate rejection, accounting and reset. It also checks evaluator completion latency, busy-start rejection, core waiting and single crediting, and reset cancellation during evaluation.

The measured multicycle experiment (`e6e9840`) increased utilization from
68.086% at `989fd40` to 70.431%, while wire length fell from 66,630 to 59,182 um.
Flip-flops increased from 157 to 188, and clock cells from 68 to 138. This
implementation is an area regression and is excluded from the proposed
area-saving combination. The supplied run screenshot shows GDS, gate-level
test, and viewer success with precheck still running; final precheck status
and timing metrics were not supplied. See
[optimization observations](potential-optimizations.md) for the comparison
and next experiment. Passing behavioral simulation alone does not establish
timing closure.
