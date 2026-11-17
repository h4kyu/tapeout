"""Physical controls and read-only diagnostics; no poker-state input policy."""

import os
import select
import time


def validate_input(event):
    if not isinstance(event, dict):
        raise ValueError("Expected an input event")
    control = event.get("control")
    if control in ("deal", "reset"):
        if set(event) != {"control", "pressed"} or type(event["pressed"]) is not bool:
            raise ValueError("Expected a boolean button level")
    elif control == "hold":
        if set(event) != {"control", "index"} or type(event["index"]) is not int or not 1 <= event["index"] <= 5:
            raise ValueError("Hold switch index must be between 1 and 5")
    elif control == "quit":
        if set(event) != {"control"}:
            raise ValueError("Unexpected quit parameters")
    else:
        raise ValueError("Unknown control")
    return dict(event)


class BoardControls:
    def __init__(self, sim):
        self.sim = sim

    def apply(self, event):
        event = validate_input(event)
        control = event["control"]
        if control == "quit":
            return False
        if control == "hold":
            self.sim.set_switches(self.sim.holds ^ (1 << (event["index"] - 1)))
        elif control == "deal":
            self.sim.set_deal_level(event["pressed"])
        elif control == "reset":
            self.sim.set_reset_level(event["pressed"])
        return True

    def render(self):
        switches = " ".join(f"{i+1}:{'ON' if self.sim.holds & (1 << i) else 'OFF'}" for i in range(5))
        return "\n".join((
            self.sim.snapshot().ascii(),
            f"Switches: {switches}",
            f"Deal/Draw pin: {'DOWN' if self.sim.deal_pressed else 'UP'} | "
            f"Reset pin: {'DOWN' if self.sim.reset_active else 'UP'} | Seed input: {self.sim.seed}",
            f"Clocks: {self.sim.cycles:,} | Accepted pulses: {self.sim.accepted_presses}",
            f"Debounce: {self.sim.debounce_cycles:,} simulated clocks",
            "Continuous, uncapped simulation; RTL decides how inputs affect the game.",
        ))


async def run_terminal(sim, keyboard, display):
    """TTYs have no key-up events: Space/R explicitly toggle button levels."""
    import termios
    import tty

    board = BoardControls(sim)
    fd = keyboard.fileno()
    previous = termios.tcgetattr(fd)
    next_render = 0
    try:
        tty.setcbreak(fd)
        settings = termios.tcgetattr(fd)
        settings[3] &= ~termios.ISIG
        termios.tcsetattr(fd, termios.TCSANOW, settings)
        display.write("\x1b[?1049h\x1b[?25l")
        while True:
            for _ in range(16):
                if not select.select([fd], [], [], 0)[0]:
                    break
                key = os.read(fd, 1).decode("utf-8", errors="ignore").lower()
                if not key or key in ("q", "\x03", "\x04"):
                    return
                if key in "12345":
                    event = {"control": "hold", "index": int(key)}
                elif key == " ":
                    event = {"control": "deal", "pressed": not sim.deal_pressed}
                elif key == "r":
                    event = {"control": "reset", "pressed": not sim.reset_active}
                else:
                    continue
                board.apply(event)
                await sim.advance(1)  # Sample ordered physical edges, not a scripted action.
            await sim.advance(800)
            if time.monotonic() >= next_render:
                display.write("\x1b[H\x1b[2J" + board.render() +
                              "\nSpace: toggle Deal/Draw DOWN/UP | R: toggle Reset DOWN/UP\n"
                              "1-5: switches | Q: quit | Clock runs while waiting for keys\n")
                display.flush()
                next_render = time.monotonic() + .2
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, previous)
        display.write("\x1b[?25h\x1b[?1049l")
        display.flush()
