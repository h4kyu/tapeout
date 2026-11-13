"""Exercise the same command loop used by make play, without human input."""

import cocotb

from sim.poker_sim import PokerSim
from sim.poker_controls import PokerTerminal, GameScreen
from test_core import PAYOUTS, reference


@cocotb.test()
async def terminal_commands(dut):
    if int(dut.GATE_LEVEL.value):
        return
    sim = PokerSim(dut)
    output = []
    terminal = PokerTerminal(sim, output.append)
    await sim.reset()

    async def reject(command):
        before, cycles = sim.snapshot(), sim.cycles
        try:
            await terminal.command(command)
        except ValueError:
            pass
        else:
            assert False, f"Accepted invalid command: {command}"
        assert sim.snapshot() == before
        assert sim.cycles == cycles

    for command in ("draw", "hold 1", "reset -1", "reset 256", "reset abc", "deal extra", "wat"):
        await reject(command)

    await terminal.command("deal")
    initial = sim.snapshot()
    assert initial.state == 2 and initial.balance == 95
    for command in ("deal", "hold", "hold 0", "hold 6", "hold x", "hold none 2"):
        await reject(command)
    await terminal.command("hold 1 3")
    assert sim.snapshot().holds == 5
    await terminal.command("hold none")
    assert sim.snapshot().holds == 0
    await terminal.command("hold 1 3")
    await terminal.command("draw")
    result = sim.snapshot()
    assert result.state == 5
    assert result.cards[0] == initial.cards[0]
    assert result.cards[2] == initial.cards[2]
    assert result.category == reference(result.cards)
    assert result.balance == 95 + PAYOUTS[result.category]
    await reject("draw")
    await terminal.command("deal")
    assert sim.snapshot().balance == result.balance - 5

    # Drive the real loop, including recoverable errors, help, reset and quit.
    commands = iter(("reset 0", "draw", "help", "show", "deal", "hold 1 2 3 4 5", "draw", "quit"))
    await terminal.run(lambda prompt: next(commands))
    assert sim.snapshot().balance == 95 + sim.snapshot().payout
    assert any(line.startswith("Error:") for line in output)
    assert output[-1] == "Goodbye."

    def end_of_input(prompt):
        raise EOFError

    await terminal.run(end_of_input)
    assert output[-1] == "\nGoodbye."


@cocotb.test()
async def game_screen_and_button_profiles(dut):
    if int(dut.GATE_LEVEL.value):
        return
    sim = PokerSim(dut)
    await sim.reset()
    screen = GameScreen(sim)
    assert "CREDITS   100" in screen.render()

    # The short profile physically drives the button, but must not cause action.
    await screen.key("b")  # bounce
    await screen.key("b")  # short
    await screen.key(" ")
    assert sim.snapshot().state == 0
    assert sim.snapshot().balance == 100
    assert sim.accepted_presses == 0
    assert "rejected by debounce" in screen.render()

    await screen.key("b")  # long: held through initial deal completion
    await screen.key(" ")
    assert sim.snapshot().state == 2
    assert sim.snapshot().balance == 95
    assert sim.accepted_presses == 1
    initial = sim.snapshot().cards
    await screen.key("1")
    await screen.key("3")
    assert sim.snapshot().holds == 5
    assert "HELD" in screen.render()
    await screen.key("1")
    assert sim.snapshot().holds == 4
    await screen.key("1")

    await screen.key("b")  # clean
    await screen.key("b")  # bounce: press and release chatter, one action
    await screen.key(" ")
    result = sim.snapshot()
    assert result.state == 5
    assert sim.accepted_presses == 2
    assert result.cards[0] == initial[0] and result.cards[2] == initial[2]
    assert result.category == reference(result.cards)
    assert result.balance == 95 + PAYOUTS[result.category]
    assert "RESULT:" in screen.render()
    assert "Accepted presses: 2" in screen.render()

    # Stable release after chatter rearms the next press.
    await screen.key(" ")
    assert sim.snapshot().state == 2
    assert sim.accepted_presses == 3
    await screen.key("r")
    assert sim.snapshot().balance == 100
    assert sim.snapshot().state == 0
    assert sim.accepted_presses == 0
    assert not await screen.key("q")
    assert not await screen.key("\x03")  # Ctrl-C is an exit key, not SIGINT.
    assert not await screen.key("\x04")
