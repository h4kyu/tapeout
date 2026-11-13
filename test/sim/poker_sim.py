"""Shared external-pin driver for the terminal and VGA RTL frontends."""

from dataclasses import dataclass
from pathlib import Path


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


class CocotbDriver:
    """Advance a 25 MHz RTL simulation only when an operation requests cycles.

    All writes target top-level input pins. Internal wires are read only.
    Do not run a separate clock task while using this driver.
    """

    def __init__(self, dut, batch_clocks=False):
        if int(dut.GATE_LEVEL.value):
            raise ValueError("Interactive frontends require RTL game-state wires")
        self.dut = dut
        self.game = dut.user_project
        self.cycles = 0
        self.accepted_presses = 0
        self.debounce_cycles = int(self.game.DEBOUNCE_CYCLES.value)
        self.cycle_observers = []
        self.batch_clocks = batch_clocks
        self.pin_stream = None
        if batch_clocks:
            Path("output").mkdir(exist_ok=True)

    def close(self):
        if self.pin_stream is not None:
            self.pin_stream.close()
            self.pin_stream = None

    async def advance(self, cycles=1):
        from cocotb.triggers import RisingEdge, Timer
        if self.batch_clocks:
            if cycles <= 0:
                return
            self.dut.preview_cycles.value = cycles
            self.dut.preview_start.value = 1
            await RisingEdge(self.dut.preview_done)
            await Timer(1, unit="ns")
            self.dut.preview_start.value = 0
            await Timer(1, unit="ns")
            if self.pin_stream is None:
                self.pin_stream = Path("output/vga-pins.bin").open("rb")
            self.pin_stream.seek(0)
            samples = self.pin_stream.read(cycles)
            if len(samples) != cycles:
                raise RuntimeError("Incomplete HDL VGA capture batch")
            reset = not int(self.dut.rst_n.value)
            for observer in self.cycle_observers:
                for pins in samples:
                    observer(pins, reset)
            self.accepted_presses += int(self.dut.preview_presses.value)
            self.cycles += cycles
            return
        for _ in range(cycles):
            self.dut.clk.value = 0
            await Timer(20, unit="ns")
            if self.cycle_observers:
                pins = self.dut.uo_out.value
                pins = int(pins) if pins.is_resolvable else None
                reset = not int(self.dut.rst_n.value)
                for observer in self.cycle_observers:
                    observer(pins, reset)
            if int(self.game.deal_draw_pulse.value):
                self.accepted_presses += 1
            self.dut.clk.value = 1
            await Timer(20, unit="ns")
            self.cycles += 1

    def write(self, **pins):
        for name, value in pins.items():
            getattr(self.dut, name).value = value

    def snapshot(self):
        packed = int(self.game.cards.value)
        state = int(self.game.state.value)
        balance = int(self.game.balance.value)
        return Snapshot(
            state=state,
            cards=tuple((packed >> (6 * i)) & 63 for i in range(5)),
            holds=int(self.game.held_cards.value),
            balance=balance,
            category=int(self.game.result_category.value),
            payout=int(self.game.result_payout.value),
            can_deal=state in (0, 5) and balance >= 5,
        )


class PokerSim:
    """Shared gameplay operations. One task owns pins and complete clock cycles."""

    def __init__(self, dut=None, batch_clocks=False, *, driver=None):
        self.driver = driver if driver is not None else CocotbDriver(dut, batch_clocks)
        self.holds = 0
        self.debounce_cycles = self.driver.debounce_cycles
        self.cycle_observers = self.driver.cycle_observers
        # Preserve existing callers inspecting the Cocotb model.
        self.dut = getattr(self.driver, "dut", None)
        self.game = getattr(self.driver, "game", None)

    @classmethod
    def native(cls, debounce_cycles=5, decode=True):
        from sim.native_sim import NativeDriver
        return cls(driver=NativeDriver(debounce_cycles, decode))

    @property
    def cycles(self):
        return self.driver.cycles

    @cycles.setter
    def cycles(self, value):
        self.driver.cycles = value

    @property
    def accepted_presses(self):
        return self.driver.accepted_presses

    @accepted_presses.setter
    def accepted_presses(self, value):
        self.driver.accepted_presses = value

    def close(self):
        self.driver.close()

    def observe_cycles(self, observer):
        """Observe settled pins each cycle, including reset and button operations.

        observer(pins, reset) is synchronous; pins=None represents Icarus X/Z.
        Native traces are copied in bounded batches only while observers exist.
        """
        self.cycle_observers.append(observer)

    async def advance(self, cycles=1):
        if cycles < 0:
            raise ValueError("Cycle count cannot be negative")
        await self.driver.advance(cycles)

    def snapshot(self):
        return self.driver.snapshot()

    async def reset(self, seed=42):
        if not 0 <= seed <= 255:
            raise ValueError("Seed must be between 0 and 255")
        self.holds = 0
        self.cycles = 0
        self.accepted_presses = 0
        self.driver.write(clk=0, ena=1, ui_in=0, uio_in=seed, rst_n=0)
        await self.advance(3)
        self.driver.write(rst_n=1)
        await self.advance(3)
        return self.snapshot()

    async def set_holds(self, *positions):
        if any(i not in range(1, 6) for i in positions):
            raise ValueError("Hold positions must be between 1 and 5")
        self.holds = sum(1 << (i - 1) for i in set(positions))
        self.driver.write(ui_in=self.holds)
        # Two synchronization edges plus one for the HOLD-state register.
        await self.advance(3)
        return self.snapshot()

    async def press_deal_draw(self, profile="clean"):
        if profile not in ("clean", "bounce", "short", "long"):
            raise ValueError("Unknown button profile")
        interval = self.debounce_cycles + 4

        async def level(pressed, cycles):
            self.driver.write(ui_in=self.holds | (32 if pressed else 0))
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
