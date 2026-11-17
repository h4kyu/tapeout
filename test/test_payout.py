"""Experimental layout: payout removal leaves the original green backdrop."""
import cocotb
from sim.poker_sim import PokerSim
from sim.vga_capture import VGACapture, FRAME_CLOCKS

@cocotb.test()
async def payout_sheet_text(dut):
    if int(dut.GATE_LEVEL.value):
        return
    sim=PokerSim(dut,batch_clocks=True)
    capture=VGACapture()
    sim.observe_cycles(capture.sample)
    try:
        await sim.reset()
        await sim.advance(2*FRAME_CLOCKS)
        assert capture.errors==0 and capture.latest is not None
        assert capture.latest.rgb[:196*640*3] == bytes((0,170,0))*(196*640)
    finally:
        sim.close()
