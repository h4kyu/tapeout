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
