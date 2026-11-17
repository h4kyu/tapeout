# Live board controls and scripted tests

The live browser and default terminal use `BoardControls`. Input handling never
reads poker state, checks credits, waits for a deal/draw to finish, generates
button profiles, or modifies core outputs. Diagnostics may read game state.

## Live controls

- Keys/buttons 1–5 toggle `ui_in[4:0]` in any state. They never release a held
  Deal/Draw button, and switches stay set across deals and reset.
- In the browser, holding Space or the Deal/Draw pointer button drives
  `ui_in[5]` high; releasing drives it low. Holding R or the Reset pointer button
  asserts `rst_n=0`; releasing deasserts it. The RTL decides whether a press is
  accepted, ignored, too short, or still waiting for debounce.
- Browser keyboard and pointer events are serialized and combined per input.
  Releasing one input source does not release another source still holding the
  same button. Focus loss/canceled pointers release momentary buttons so a lost
  key-up cannot leave them stuck. Physical switch positions are unchanged.
- A terminal has no key-up events. Space explicitly toggles the Deal/Draw level
  DOWN/UP; R toggles the Reset level DOWN/UP. Press again to release. This is not
  a synthesized click waveform. The terminal polls input without blocking the
  simulation clock. For long terminal sessions,
  `make play COCOTB_PLUSARGS=+NO_WAVES` avoids growing a waveform file.
- Q stops the viewer. It is a simulator control, not a game action.

One simulation task owns the model and advances continuous, uncapped clock
batches. HTTP threads only enqueue `/input` events and read immutable status.
Every queued input is sampled for at least one clock before applying the next
edge, preserving event order without waiting for game progress. Simulation
speed determines how simulated time relates to wall time.

Browser playback defaults to production debounce (500,000 cycles); set
`VGA_DEBOUNCE_CYCLES` explicitly to override it. Headless capture and the Cocotb
terminal testbench retain their five-cycle defaults. The displayed diagnostics
show the actual configured value.

The seed is configured on startup (`VGA_SEED`, default 42, in the native viewer).
Live reset only changes `rst_n`: it does not change seed, switches, button level,
clock count, or diagnostic pulse count. A button left held through reset remains
held when reset is released, exactly as an input pin would.

## Switches and held cards

`PokerSim.holds` is the physical switch mask. `snapshot().holds` is the core's
`held_cards`: it follows synchronized switches in HOLD and stays frozen through
DRAWING/RESULT. Browser ON/OFF buttons show `switch_mask`; VGA HOLD labels and
HELD diagnostics show `held_cards`. The status JSON also reports `deal_pressed`,
`reset_active`, and `seed` as physical input state.

## Explicit scripted helpers

Tests, `POKER_LINE_MODE=1 make play`, and optional `VGA_COMMANDS` setup use
`poker_controls.py` helpers. Their `deal`/`draw` commands, state waits, button
profiles, and fresh-session reset are deliberate scenario automation, not live
controls. `GameScreen` remains a scripted test helper; no live frontend uses it.

Raw `set_switches`, `set_deal_level`, and `set_reset_level` change pins without
advancing clocks. Scripted `set_holds`, `press_deal_draw`, `wait_for_state`, and
`reset` remain available. `reset(seed, preserve_switches=True)` is a scripted
reset retaining switches; the default `reset()` initializes a fresh test session.
Neither is used by the live reset button.
