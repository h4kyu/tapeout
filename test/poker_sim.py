"""External-pin driver and read-only RTL display for the pre-VGA simulator."""

from dataclasses import dataclass

from cocotb.triggers import Timer


STATES = ("IDLE", "DEALING", "HOLD", "DRAWING", "EVALUATE", "RESULT")
CATEGORIES = (
    "No qualifying hand", "Jacks or better", "Two pair", "Three of a kind",
    "Straight", "Flush", "Full house", "Four of a kind", "Straight flush",
    "Royal flush",
)


@dataclass(frozen=True)
class Snapshot:
    state: int
    cards: tuple[int, ...]
    holds: int
    balance: int
    category: int
    payout: int
    can_deal: bool

    def ascii(self):
        def card_text(card):
            rank = card & 15
            if not 2 <= rank <= 14:
                return "--"
            label = {11: "J", 12: "Q", 13: "K", 14: "A"}.get(rank, str(rank))
            return f"{label}{'CDHS'[card >> 4]}"

        lines = [
            f"VIDEO POKER | Balance: {self.balance} | {STATES[self.state]}",
            "Card    " + " ".join(f"{i:^6}" for i in range(1, 6)),
            "        " + " ".join(f"{'[' + card_text(c) + ']':^6}" for c in self.cards),
            "Hold    " + " ".join(f"{'*' if self.holds & (1 << i) else '':^6}" for i in range(5)),
        ]
        if self.state == 5:
            lines.append(f"Result: {CATEGORIES[self.category]} | Payout: {self.payout}")
        if self.state in (0, 5) and not self.can_deal:
            lines.append("Insufficient credits: reset to start a new session.")
        return "\n".join(line.rstrip() for line in lines)


class PokerSim:
    """Advance a 25 MHz RTL simulation only when an operation requests cycles.

    All writes target top-level input pins. Internal wires are read only.
    Do not run a separate clock task while using this driver.
    """

    def __init__(self, dut):
        if int(dut.GATE_LEVEL.value):
            raise ValueError("The ASCII display requires RTL game-state wires")
        self.dut = dut
        self.game = dut.user_project
        self.holds = 0
        self.cycles = 0
        self.accepted_presses = 0
        self.debounce_cycles = int(self.game.DEBOUNCE_CYCLES.value)

    async def advance(self, cycles=1):
        for _ in range(cycles):
            self.dut.clk.value = 0
            await Timer(20, unit="ns")
            if int(self.game.deal_draw_pulse.value):
                self.accepted_presses += 1
            self.dut.clk.value = 1
            await Timer(20, unit="ns")
            self.cycles += 1

    async def reset(self, seed=42):
        if not 0 <= seed <= 255:
            raise ValueError("Seed must be between 0 and 255")
        self.holds = 0
        self.cycles = 0
        self.accepted_presses = 0
        self.dut.clk.value = 0
        self.dut.ena.value = 1
        self.dut.ui_in.value = 0
        self.dut.uio_in.value = seed
        self.dut.rst_n.value = 0
        await self.advance(3)
        self.dut.rst_n.value = 1
        await self.advance(3)
        return self.snapshot()

    async def set_holds(self, *positions):
        if any(i not in range(1, 6) for i in positions):
            raise ValueError("Hold positions must be between 1 and 5")
        self.holds = sum(1 << (i - 1) for i in set(positions))
        self.dut.ui_in.value = self.holds
        # Two synchronization edges plus one for the HOLD-state register.
        await self.advance(3)
        return self.snapshot()

    async def press_deal_draw(self, profile="clean"):
        if profile not in ("clean", "bounce", "short", "long"):
            raise ValueError("Unknown button profile")
        interval = self.debounce_cycles + 4

        async def level(pressed, cycles):
            self.dut.ui_in.value = self.holds | (32 if pressed else 0)
            await self.advance(cycles)

        if profile == "bounce":
            for _ in range(3):
                await level(True, 1)
                await level(False, 1)
        await level(True, max(1, self.debounce_cycles // 2) if profile == "short"
                    else interval + (512 if profile == "long" else 0))
        if profile == "bounce":
            for _ in range(3):
                await level(False, 1)
                await level(True, 1)
        await level(False, interval)

    async def wait_for_state(self, state, timeout_cycles=1024):
        for _ in range(timeout_cycles):
            if self.snapshot().state == state:
                return self.snapshot()
            await self.advance()
        raise TimeoutError(f"Waiting for {STATES[state]}: {self.snapshot()}")

    def snapshot(self):
        packed = int(self.game.cards.value)
        return Snapshot(
            state=int(self.game.state.value),
            cards=tuple((packed >> (6 * i)) & 63 for i in range(5)),
            holds=int(self.game.held_cards.value),
            balance=int(self.game.balance.value),
            category=int(self.game.result_category.value),
            payout=int(self.game.result_payout.value),
            can_deal=bool(int(self.game.can_deal.value)),
        )
