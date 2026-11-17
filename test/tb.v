`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();
`ifdef GL_TEST
  localparam GATE_LEVEL = 1;
`else
  localparam GATE_LEVEL = 0;
`endif

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    if (!$test$plusargs("NO_WAVES")) begin
      $dumpfile("tb.fst");
      $dumpvars(0, tb);
    end
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

`ifndef GL_TEST
  // Verification acceleration: execute a requested batch entirely in HDL,
  // exporting one byte of external pins per pixel clock. Normal tests never
  // assert preview_start and continue to drive clk themselves.
  reg preview_start = 0;
  reg preview_done = 0;
  reg [31:0] preview_cycles = 0;
  reg [31:0] preview_presses = 0;
  integer preview_file = 0;
  integer preview_i;
  integer preview_seek;
  always @(posedge preview_start) begin
    preview_done = 0;
    preview_presses = 0;
    if (preview_file == 0) begin
      preview_file = $fopen("output/vga-pins.bin", "wb");
      if (preview_file == 0) $fatal(1, "Cannot open VGA pin capture file");
    end
    // Reuse one bounded batch buffer, rather than grow a file forever.
    preview_seek = $fseek(preview_file, 0, 0);
    if (preview_seek != 0) $fatal(1, "Cannot rewind VGA pin capture file");
    for (preview_i = 0; preview_i < preview_cycles; preview_i = preview_i + 1) begin
      clk = 0;
      #20;
      if ($isunknown(uo_out)) $fatal(1, "Unknown X/Z on VGA output pins");
      $fwrite(preview_file, "%c", uo_out);
      if (user_project.deal_draw_pulse) preview_presses = preview_presses + 1;
      clk = 1;
      #20;
    end
    $fflush(preview_file);
    preview_done = 1;
  end
`endif

  // Standalone combinational font lookup, also tested in gate-level runs.
  reg [5:0] font_character = 0;
  reg [3:0] font_row = 0;
  wire [11:0] font_pixels;

  font_rom font_unit (
      .character(font_character), .row(font_row), .pixels(font_pixels)
  );

  // Standalone HOLD-label geometry, with no font ROM inside the label module.
  reg [9:0] hold_x;
  reg [9:0] hold_y;
  reg [4:0] hold_selected;
  wire hold_text_active;
  wire [5:0] hold_character;
  wire [3:0] hold_glyph_x;
  wire [3:0] hold_glyph_y;

  hold_labels hold_unit (
      .x(hold_x), .y(hold_y), .held_cards(hold_selected),
      .text_active(hold_text_active), .character(hold_character),
      .glyph_x(hold_glyph_x), .glyph_y(hold_glyph_y)
  );

  reg status_clk;
  reg status_rst_n;
  reg [9:0] status_x;
  reg [9:0] status_y;
  reg [15:0] status_balance;
  reg [2:0] status_state = 0;
  reg [11:0] status_payout = 0;
  wire status_text_active;
  wire [5:0] status_character;
  wire [3:0] status_glyph_x;
  wire [3:0] status_glyph_y;

  credits_bet status_unit (
      .clk(status_clk), .rst_n(status_rst_n), .x(status_x), .y(status_y),
      .balance(status_balance), .state(status_state), .payout(status_payout),
      .text_active(status_text_active),
      .character(status_character), .glyph_x(status_glyph_x), .glyph_y(status_glyph_y)
  );

  reg [9:0] message_x;
  reg [9:0] message_y;
  reg [2:0] message_state;
  reg [3:0] message_live_category;
  reg [3:0] message_result_category;
  wire message_active;
  wire message_yellow;
  wire [3:0] message_text_row;
  wire [3:0] message_text_column;
  wire [3:0] message_glyph_x;
  wire [3:0] message_glyph_y;
  wire [5:0] message_character;

  hand_message message_unit (
      .x(message_x), .y(message_y), .state(message_state),
      .hand_category(message_live_category), .result_category(message_result_category),
      .text_active(message_active), .yellow(message_yellow),
      .text_row(message_text_row), .text_column(message_text_column),
      .glyph_x(message_glyph_x), .glyph_y(message_glyph_y)
  );
  payout_characters message_words (
      .numbers(1'b0), .text_row(message_text_row), .column(message_text_column),
      .character(message_character)
  );

  reg [9:0] card_x;
  reg [9:0] card_y;
  reg [29:0] card_values;
  wire card_active;
  wire card_text_active;
  wire [5:0] card_character;
  wire [3:0] card_glyph_x;
  wire [3:0] card_glyph_y;
  wire card_red;

  card_faces card_unit (
      .x(card_x), .y(card_y), .cards(card_values), .active(card_active),
      .text_active(card_text_active), .character(card_character),
      .glyph_x(card_glyph_x), .glyph_y(card_glyph_y), .red_suit(card_red)
  );

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

  // Standalone player input adapter.
  reg inputs_clk = 0;
  reg inputs_rst_n = 1;
  reg inputs_button = 0;
  reg [4:0] inputs_holds = 0;
  wire inputs_pulse;
  wire [4:0] inputs_hold_mask;

  poker_inputs #(.DEBOUNCE_CYCLES(5)) inputs_unit (
      .clk(inputs_clk), .rst_n(inputs_rst_n),
      .deal_draw_in(inputs_button), .hold_in(inputs_holds),
      .deal_draw_pulse(inputs_pulse), .hold_mask(inputs_hold_mask)
  );

  // Standalone PRNG unit
  reg prng_clk;
  reg prng_rst_n;
  reg [7:0] prng_seed;
  wire [5:0] prng_rand_num;
  wire prng_ready;

  prng prng_unit (
    .seed      (prng_seed),
    .rand_num  (prng_rand_num),
    .prng_ready(prng_ready),
    .clk       (prng_clk),
    .rst_n     (prng_rst_n)
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
  wire [3:0] core_hand_category;
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
      .hand_category(core_hand_category), .result_category(core_result_category), .result_payout(core_result_payout),
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

  tt_um_h4kyu_video_poker
`ifndef GL_TEST
  #(.DEBOUNCE_CYCLES(5))
`endif
  user_project (

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
