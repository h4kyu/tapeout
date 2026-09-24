/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * 8-bit programmable counter
 *
 * ui_in[0]   = synchronous load
 * ui_in[1]   = output enable
 * uio_in     = value to load
 * uio_out    = counter value
 * uio_oe     = bidirectional pin direction
 */

`default_nettype none

module tt_um_h4kyu_8bit_counter (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  wire load;
  wire output_enable;

  assign load = ui_in[0];
  assign output_enable = ui_in[1];

  reg [7:0] counter;  // current 8-bit count

  /*
   * counter state
   *
   * reset asynchronously on rst_n = 0.
   * load uio_in synchronously on high load
   * otherwise increment counter
   */
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      counter <= 8'b0000_0000;
    else if (load)
      counter <= uio_in;
    else
      counter <= counter + 8'b0000_0001;
  end

  assign uio_out = counter;

  /*
   * ui_in[1] = 0 -> uio_oe = 8'b00000000
   * ui_in[1] = 1 -> uio_oe = 8'b11111111
   */
  assign uio_oe  = {8{output_enable}};

  // unused
  assign uo_out = 8'b0000_0000;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:2], 1'b0};

endmodule
