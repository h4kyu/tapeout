"""Cocotb terminal entrypoint; controls are also usable by native Python."""
import os
import cocotb
from sim.poker_sim import PokerSim
from sim.poker_controls import GameScreen, PokerTerminal, HELP

@cocotb.test()
async def interactive_poker(dut):
    sim = PokerSim(dut)
    await sim.reset()
    if os.environ.get("POKER_LINE_MODE") == "1":
        await PokerTerminal(sim).run()
        return
    try:
        keyboard = open("/dev/tty", "r")
    except OSError as error:
        raise RuntimeError("No controlling terminal. Run make play in a terminal, "
                           "or use POKER_LINE_MODE=1 make play for line commands.") from error
    with keyboard, open("/dev/tty", "w", buffering=1) as display:
        await GameScreen(sim).run(keyboard, display)
