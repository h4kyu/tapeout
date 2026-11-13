/*
 * Copyright (c) 2024 Nash Weissberg & Luke Zhan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_h4kyu_video_poker #(
    parameter integer DEBOUNCE_CYCLES = 500_000
) (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Assign unused output pins to 0
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire deal_draw_pulse;
  wire [4:0] hold_mask;

  poker_inputs #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) player_inputs (
    .clk(clk), .rst_n(rst_n),
    .deal_draw_in(ui_in[5]), .hold_in(ui_in[4:0]),
    .deal_draw_pulse(deal_draw_pulse), .hold_mask(hold_mask)
  );

  // Pseudorandom number generator

  wire [5:0] candidate;
  wire prng_ready;

  prng rand_num_generator (
    .seed      (uio_in),
    .rand_num  (candidate),
    .prng_ready(prng_ready),
    .clk       (clk),
    .rst_n     (rst_n)
  );

  // Shared game-state interface for the renderer and RTL simulation display.
  wire [29:0] cards;
  wire [4:0] held_cards;
  wire [2:0] state;
  wire [15:0] balance;
  wire [3:0] result_category;
  wire [11:0] result_payout;
  wire can_deal;
  wire unused_dealer_ready;
  wire [51:0] unused_dealt_mask;

  poker_core game (
    .clk(clk), .rst_n(rst_n),
    .deal_draw_pulse(deal_draw_pulse), .hold_mask(hold_mask),
    .candidate(candidate), .prng_ready(prng_ready),
    .dealer_ready(unused_dealer_ready), .dealt_mask(unused_dealt_mask),
    .cards(cards), .held_cards(held_cards), .state(state),
    .balance(balance), .result_category(result_category),
    .result_payout(result_payout), .can_deal(can_deal)
  );

  // Temporary status pins until Luke's VGA renderer is connected.
  // Keep the game observable to synthesis; this is not a VGA signal.
  assign uo_out = {can_deal, state, result_category};

  // List intentionally unused signals to prevent warnings.
  wire _unused = &{ena, ui_in[7:6], cards, held_cards,
                   balance, result_payout, unused_dealer_ready,
                   unused_dealt_mask, 1'b0};

endmodule
