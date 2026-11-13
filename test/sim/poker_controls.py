"""Interactive terminal controls for the RTL poker simulator."""

import os
from collections import deque

from sim.poker_sim import PokerSim, STATES, CATEGORIES


HELP = """Commands:
  deal          Start a round (costs 5 credits)
  hold 1 3      Select exactly these card positions to hold
  hold none     Clear the hold selection
  draw          Replace unheld cards and show the result
  reset [seed]  Restore 100 credits (default seed: 42; range: 0..255)
  show          Show the current hand
  help          Show commands
  quit          Exit
C=clubs D=diamonds H=hearts S=spades. Time pauses at the prompt."""


class PokerTerminal:
    def __init__(self, sim, output=print):
        self.sim = sim
        self.output = output

    def show(self):
        self.output(f"[cycle {self.sim.cycles}]\n{self.sim.snapshot().ascii()}")

    async def command(self, line):
        """Return False to quit; reject invalid commands before touching inputs."""
        words = line.lower().split()
        if not words:
            return True
        command, *args = words
        state = self.sim.snapshot()
        if command in ("quit", "exit") and not args:
            self.output("Goodbye.")
            return False
        if command == "help" and not args:
            self.output(HELP)
            return True
        if command == "show" and not args:
            self.show()
            return True
        if command == "reset" and len(args) <= 1:
            try:
                seed = int(args[0]) if args else 42
            except ValueError:
                raise ValueError("Seed must be an integer between 0 and 255") from None
            await self.sim.reset(seed)
        elif command == "deal" and not args:
            if state.state not in (0, 5):
                raise ValueError("Finish the current round with draw before dealing again")
            if not state.can_deal:
                raise ValueError("Insufficient credits: use reset to start a new session")
            await self.sim.set_holds()
            await self.sim.press_deal_draw()
            await self.sim.wait_for_state(2)
        elif command == "hold":
            if state.state != 2:
                raise ValueError("Deal a hand before selecting holds")
            if args == ["none"]:
                positions = []
            else:
                try:
                    positions = [int(arg) for arg in args]
                except ValueError:
                    raise ValueError("Use hold 1 3 or hold none") from None
                if not positions or any(i not in range(1, 6) for i in positions):
                    raise ValueError("Hold positions must be between 1 and 5; use hold none to clear")
            await self.sim.set_holds(*positions)
        elif command == "draw" and not args:
            if state.state != 2:
                raise ValueError("Deal a hand before drawing")
            await self.sim.press_deal_draw()
            await self.sim.wait_for_state(5)
        else:
            raise ValueError("Unknown command or arguments; type help for commands")
        self.show()
        return True

    async def run(self, read_line=input):
        self.output(HELP)
        self.show()
        while True:
            try:
                # No clock task is running: RTL time stays paused during input.
                line = read_line("poker> ")
            except (EOFError, KeyboardInterrupt):
                self.output("\nGoodbye.")
                return
            try:
                if not await self.command(line):
                    return
            except ValueError as error:
                self.output(f"Error: {error}")


class GameScreen:
    """Small, single-key game view; all actions still use external RTL inputs."""

    PROFILES = ("clean", "bounce", "short", "long")

    def __init__(self, sim):
        self.sim = sim
        self.profile = 0
        self.messages = deque(["Space to deal. Keys 1-5 toggle holds after dealing."], maxlen=4)

    def render(self):
        state = self.sim.snapshot()
        lines = [
            "VIDEO POKER                                      RTL SIMULATION",
            "=" * 70,
            f"CREDITS {state.balance:5}    BET 5    PAYOUT {state.payout:4}    {STATES[state.state]}",
            "",
        ]
        labels = []
        suits = []
        for card in state.cards:
            rank = card & 15
            valid = 2 <= rank <= 14
            labels.append({11: "J", 12: "Q", 13: "K", 14: "A"}.get(rank, str(rank)) if valid else "--")
            suits.append(("CLUBS", "DIAMONDS", "HEARTS", "SPADES")[card >> 4] if valid else "")
        lines += [
            "  " + "  ".join("+----------+" for _ in range(5)),
            "  " + "  ".join(f"| {label:<8} |" for label in labels),
            "  " + "  ".join(f"|{suit:^10}|" for suit in suits),
            "  " + "  ".join(f"| {label:>8} |" for label in labels),
            "  " + "  ".join("+----------+" for _ in range(5)),
            "  " + "  ".join(f"{'HELD' if state.holds & (1 << i) else '':^12}" for i in range(5)),
            "  " + "  ".join(f"{'[' + str(i) + ']':^12}" for i in range(1, 6)),
            "",
        ]
        if state.state == 5:
            lines.append(f"RESULT: {CATEGORIES[state.category]}  (+{state.payout} credits)")
        elif state.state == 2:
            lines.append("Choose cards to keep, then press Space to draw.")
        else:
            lines.append("Press Space to deal." if state.can_deal else "Not enough credits. Press R to reset.")
        profile = self.PROFILES[self.profile]
        lines += [
            "-" * 70,
            f"Button: {profile.upper():6}   Accepted presses: {self.sim.accepted_presses}   Cycle: {self.sim.cycles}",
            f"Debounce: {self.sim.debounce_cycles} cycles (accelerated testbench; hardware: 20 ms)",
            "B changes button: clean / bounce / short / long",
            "Space Deal/Draw | 1-5 Toggle hold | R Reset seed 42 | Q Quit",
            "Simulation pauses between keys. C/D/H/S suit names shown on cards.",
            "-" * 70,
            *self.messages,
        ]
        return "\n".join(lines)

    async def key(self, key):
        key = key.lower()
        state = self.sim.snapshot()
        if key in ("q", "\x03", "\x04"):
            return False
        if key == "b":
            self.profile = (self.profile + 1) % len(self.PROFILES)
            self.messages.append(f"Button profile: {self.PROFILES[self.profile]}.")
        elif key == "r":
            await self.sim.reset(42)
            self.messages.clear()
            self.messages.append("Reset: 100 credits, seed 42.")
        elif key in "12345" and len(key) == 1:
            if state.state != 2:
                self.messages.append("Deal a hand before selecting holds.")
            else:
                mask = state.holds ^ (1 << (int(key) - 1))
                await self.sim.set_holds(*(i + 1 for i in range(5) if mask & (1 << i)))
        elif key == " ":
            if state.state in (0, 5) and not state.can_deal:
                self.messages.append("Not enough credits. Press R to reset.")
                return True
            before = self.sim.accepted_presses
            profile = self.PROFILES[self.profile]
            await self.sim.press_deal_draw(profile)
            if self.sim.accepted_presses == before:
                self.messages.append(f"{profile.upper()}: rejected by debounce; no game action.")
            else:
                await self.sim.wait_for_state(5 if state.state == 2 else 2)
                count = self.sim.accepted_presses - before
                self.messages.append(f"{profile.upper()}: {count} accepted press; {'draw' if state.state == 2 else 'deal'} complete.")
        return True

    async def run(self, keyboard, display):
        # Use the controlling terminal, not simulator-wrapped Python stdio.
        import termios
        import tty

        fd = keyboard.fileno()
        previous = termios.tcgetattr(fd)
        try:
            tty.setcbreak(fd)
            # Deliver Ctrl-C as a key instead of signaling the simulator/make tree.
            settings = termios.tcgetattr(fd)
            settings[3] &= ~termios.ISIG
            termios.tcsetattr(fd, termios.TCSANOW, settings)
            display.write("\x1b[?1049h\x1b[?25l")
            while True:
                display.write("\x1b[H\x1b[2J" + self.render())
                display.flush()
                key = os.read(fd, 1).decode("utf-8", errors="ignore")
                if not key or not await self.key(key):
                    break
        except KeyboardInterrupt:
            pass
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, previous)
            display.write("\x1b[?25h\x1b[?1049l")
            display.flush()
