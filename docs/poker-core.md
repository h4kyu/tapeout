# Poker game core

see `proposal/SystemDiagram.excalidraw` for system diagram.

implements the following modules:
- `poker_dealer.v`: five hand registers, the 52-bit used-card mask, initial deal, and selective replacement.
- `poker_evaluator.v`: combinational hand classification and fixed-wager pay table.
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
| `candidate[5:0]` | Input | Candidate card from Luke's PRNG adapter |
| `candidate_valid` | Input | Candidate is available on this edge |
| `candidate_ready` | Output | Dealer can consume a candidate on this edge |
| `cards[29:0]` | Output | Five packed hand registers |
| `dealt_mask[51:0]` | Output | All cards accepted in this round, including discards |
| `held_cards[4:0]` | Output | Hold indicators: track switches in HOLD, frozen during draw/result |
| `state[2:0]` | Output | State codes below |
| `balance[15:0]` | Output | Current credit balance |
| `result_category[3:0]` | Output | Final hand category, valid in RESULT |
| `result_payout[11:0]` | Output | Final award, valid in RESULT |
| `can_deal` | Output | Idle/result state with at least five credits |

Transfer is `candidate_valid && candidate_ready`. The producer must advance after every transfer. 
An adapter can assert valid continuously and advance the LFSR on ready. A free-running LFSR can also provide a candidate each cycle. 

`deal_draw_pulse` starts a deal or draw. Hold/unhold uses the independent `hold_mask` levels and cannot start either operation. 
Pulses while busy are ignored, not queued. The final input adapter must produce one pulse per debounced press and require a debounced release before rearming, we avoid connecting `button_out` directly to `deal_draw_pulse`.

The dealer samples `start`, `draw_mode` and the hold mask together when idle.
The evaluator is combinational, so the controller's EVALUATE state supplies a full cycle for it to settle. 

## Round and accounting rules

| State | Code | Transition |
| --- | --- | --- |
| IDLE | 0 | Accepted action deducts five credits and starts DEALING |
| DEALING | 1 | Dealer completion advances to HOLD |
| HOLD | 2 | Action captures holds and starts DRAWING |
| DRAWING | 3 | Dealer completion advances to EVALUATE |
| EVALUATE | 4 | Latch classification, credit award once, advance to RESULT |
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

Run `make -f Makefile.core` in `test/` with the pinned Python dependencies and Icarus Verilog installed. GitHub's RTL test workflow runs this target in addition to the existing wrapper and debounce tests. The core suite includes a basic deal/draw round, hold-switch independence, every hand category, 3,000 random hands, all 32 hold masks, invalid/duplicate rejection, accounting and reset.

The combinational evaluator and variable-index dealer still need synthesis and timing measurement at 25 MHz, and a tile-fit check. Passing behavioral simulation alone does not establish timing closure or fit in the currently configured tile.
