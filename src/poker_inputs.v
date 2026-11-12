`default_nettype none

// Convert asynchronous player controls to the poker core's input contract.
module poker_inputs #(
    parameter integer DEBOUNCE_CYCLES = 500_000
) (
    input wire clk,
    input wire rst_n,
    input wire deal_draw_in,
    input wire [4:0] hold_in,
    output wire deal_draw_pulse,
    output reg [4:0] hold_mask
);
    wire deal_draw_level;
    reg deal_draw_previous;
    reg [4:0] hold_sync1;

    debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) button_filter (
        .clk(clk), .rst_n(rst_n),
        .button_in(deal_draw_in), .button_out(deal_draw_level)
    );

    assign deal_draw_pulse = deal_draw_level && !deal_draw_previous;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deal_draw_previous <= 1'b0;
            hold_sync1 <= 5'b0;
            hold_mask <= 5'b0;
        end else begin
            deal_draw_previous <= deal_draw_level;
            hold_sync1 <= hold_in;
            hold_mask <= hold_sync1;
        end
    end
endmodule
