// Simulation-only diagnostics; controls still enter through the chip pins.
module poker_native # (parameter integer DEBOUNCE_CYCLES = 5) (
    input wire clk, rst_n, ena,
    input wire [7:0] ui_in, uio_in,
    output wire [7:0] uo_out,
    output wire [29:0] cards,
    output wire [4:0] holds,
    output wire [2:0] state,
    output wire [15:0] balance,
    output wire [3:0] category,
    output wire [11:0] payout,
    output wire accepted
);
    tt_um_h4kyu_video_poker #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) chip (
        .clk(clk), .rst_n(rst_n), .ena(ena), .ui_in(ui_in), .uio_in(uio_in),
        .uo_out(uo_out), .uio_out(), .uio_oe()
    );
    assign cards = chip.cards;
    assign holds = chip.held_cards;
    assign state = chip.state;
    assign balance = chip.balance;
    assign category = chip.result_category;
    assign payout = chip.result_payout;
    assign accepted = chip.deal_draw_pulse;
endmodule
