# Physical hold switches

Keys/buttons 1–5 toggle physical hold switches in every game state. The terminal
commands `hold 1 3` and `hold none` set those same switch positions. Dealing never
moves the switches, so a switch left ON applies to the next hand when the core
enters HOLD. The simulator still drives `ui_in[4:0]` through the RTL synchronizer.

Switch state and the core's held-card state are separate:

- `PokerSim.holds` is the physical switch mask driven on the input pins.
- `PokerSim.snapshot().holds` is the core's `held_cards` output. It follows
  synchronized switches in HOLD and stays frozen through DRAWING and RESULT.

The viewer's ON/OFF buttons display the physical mask (`switch_mask` in status
JSON). The VGA HOLD labels and terminal HELD indicators display the core output
(`held_cards` in status JSON). Changing switches during RESULT changes the next
hand's selection, not the completed hand's labels or outcome.

Interactive R/reset commands call `reset(seed, preserve_switches=True)`: core
state and balance reset, but switch positions stay put. A fresh simulator starts
with switches OFF. Low-level `PokerSim.reset()` keeps its original fresh-session
behavior by default; deterministic tests can explicitly request
`reset(seed, preserve_switches=False)` to clear switches too.

The terminal advances one clock after entering HOLD so the core can sample
already synchronized switch settings before the terminal pauses. No core or
input RTL is changed, and the simulator never writes `held_cards` directly.
