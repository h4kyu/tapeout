`timescale 1ns/1ps
`default_nettype none
module tb_core;
    reg clk = 0;
    reg rst_n = 1;
    reg deal_draw_pulse = 0;
    reg [4:0] hold_mask = 0;
    reg [5:0] candidate = 0;
    reg candidate_valid = 0;
    wire candidate_ready;
    wire [29:0] cards;
    wire [51:0] dealt_mask;
    wire [4:0] held_cards;
    wire [2:0] state;
    wire [15:0] balance;
    wire [3:0] result_category;
    wire [11:0] result_payout;
    wire can_deal;
    poker_core core (
        .clk(clk), .rst_n(rst_n), .deal_draw_pulse(deal_draw_pulse),
        .hold_mask(hold_mask), .candidate(candidate),
        .candidate_valid(candidate_valid), .candidate_ready(candidate_ready),
        .cards(cards), .dealt_mask(dealt_mask), .held_cards(held_cards),
        .state(state), .balance(balance), .result_category(result_category),
        .result_payout(result_payout), .can_deal(can_deal)
    );
    reg [29:0] eval_cards = 0;
    wire [3:0] eval_category;
    wire [11:0] eval_payout;
    poker_evaluator standalone_evaluator (
        .cards(eval_cards), .category(eval_category), .payout(eval_payout)
    );
endmodule
