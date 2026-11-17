"""Continuously clocked board terminal; line commands are explicit scripting."""
import os
import cocotb
from sim.poker_sim import PokerSim
from sim.poker_controls import PokerTerminal
from sim.board_controls import run_terminal


@cocotb.test()
async def interactive_poker(dut):
    line_mode = os.environ.get("POKER_LINE_MODE") == "1"
    sim = PokerSim(dut, batch_clocks=not line_mode)
    try:
        await sim.reset()
        if line_mode:
            await PokerTerminal(sim).run()
            return
        try:
            keyboard = open("/dev/tty", "r")
        except OSError as error:
            raise RuntimeError("No controlling terminal. Run make play in a terminal, "
                               "or use POKER_LINE_MODE=1 make play for scripted commands.") from error
        with keyboard, open("/dev/tty", "w", buffering=1) as display:
            await run_terminal(sim, keyboard, display)
    finally:
        sim.close()
