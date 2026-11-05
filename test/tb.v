`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Standalone debounce unit, independent of the project's button wiring.
  reg debounce_clk;
  reg debounce_rst_n;
  reg debounce_button_in;
  wire debounce_button_out;

  debounce #(.DEBOUNCE_CYCLES(5)) debounce_unit (
      .clk       (debounce_clk),
      .rst_n     (debounce_rst_n),
      .button_in (debounce_button_in),
      .button_out(debounce_button_out)
  );

  // Standalone game logic, independent of the project's input/output wiring.
  reg core_clk = 0;
  reg core_rst_n = 1;
  reg core_deal_draw_pulse = 0;
  reg [4:0] core_hold_mask = 0;
  reg [5:0] core_candidate = 0;
  reg core_prng_ready = 0;
  wire core_dealer_ready;
  wire [29:0] core_cards;
  wire [51:0] core_dealt_mask;
  wire [4:0] core_held_cards;
  wire [2:0] core_state;
  wire [15:0] core_balance;
  wire [3:0] core_result_category;
  wire [11:0] core_result_payout;
  wire core_can_deal;

  poker_core core_unit (
      .clk(core_clk), .rst_n(core_rst_n),
      .deal_draw_pulse(core_deal_draw_pulse), .hold_mask(core_hold_mask),
      .candidate(core_candidate), .prng_ready(core_prng_ready),
      .dealer_ready(core_dealer_ready), .cards(core_cards),
      .dealt_mask(core_dealt_mask), .held_cards(core_held_cards),
      .state(core_state), .balance(core_balance),
      .result_category(core_result_category), .result_payout(core_result_payout),
      .can_deal(core_can_deal)
  );

  reg [29:0] eval_cards = 0;
  wire [3:0] eval_category;
  wire [11:0] eval_payout;

  poker_evaluator evaluator_unit (
      .cards(eval_cards), .category(eval_category), .payout(eval_payout)
  );

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_h4kyu_video_poker user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
