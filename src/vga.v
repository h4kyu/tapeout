`default_nettype none

module vga (
    input  wire [29:0] cards,
    input  wire [15:0] balance,
    input  wire [4:0]  held_cards,
    input  wire [2:0]  state,
    input  wire [3:0]  result_category,
    input  wire [11:0] result_payout,
    input  wire        clk,
    input  wire        rst_n,
    output wire [1:0]  red,
    output wire [1:0]  green,
    output wire [1:0]  blue,
    output wire        hsync,
    output wire        vsync
);
    // Interface-only placeholder: no VGA timing or pixels until the next stage.
    assign red = 2'b00;
    assign green = 2'b00;
    assign blue = 2'b00;
    assign hsync = 1'b0;
    assign vsync = 1'b0;

    wire _unused = &{cards, balance, held_cards, state, result_category,
                     result_payout, clk, rst_n, 1'b0};
endmodule
