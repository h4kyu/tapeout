"""Cocotb entrypoint for auxiliary harness tests, separate from chip tests."""

from sim.poker_demo import scripted_ascii_demo
from sim.tests.test_terminal import terminal_commands, game_screen_and_button_profiles
from sim.tests.test_vga_batch import batched_clock_matches_pixel_driver
