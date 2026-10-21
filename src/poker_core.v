`default_nettype none

// core digital logic implementation
module poker_core (
    input wire clk,
    input wire rst_n,
    input wire deal_draw_pulse, 
    input wire [4:0] hold_mask, 
    input wire [5:0] candidate,
    input wire candidate_valid,
    output wire candidate_ready,
    output wire [29:0] cards,
    output wire [51:0] dealt_mask,
    output reg [4:0] held_cards,
    output reg [2:0] state,
    output reg [15:0] balance,
    output reg [3:0] result_category,
    output reg [11:0] result_payout,
    output wire can_deal
);

    localparam IDLE = 3'd0, 
               DEALING = 3'd1, 
               HOLD = 3'd2,
               DRAWING = 3'd3, 
               EVALUATE = 3'd4, 
               RESULT = 3'd5;

    wire dealer_done;
    wire dealer_busy;
    wire [3:0] category;
    wire [11:0] payout;
    wire [16:0] credited_balance = {1'b0, balance} + {5'b0, payout};
    assign can_deal = (state == IDLE || state == RESULT) && balance >= 16'd5;
    wire start_deal = deal_draw_pulse && can_deal;
    wire start_draw = deal_draw_pulse && state == HOLD;

    poker_dealer dealer (
        .clk(clk), .rst_n(rst_n), .start(start_deal || start_draw),
        .draw_mode(start_draw), .hold_mask(hold_mask),
        .candidate(candidate), .candidate_valid(candidate_valid),
        .candidate_ready(candidate_ready), .busy(dealer_busy),
        .done(dealer_done), .cards(cards), .dealt_mask(dealt_mask)
    );
    
    poker_evaluator evaluator (.cards(cards), .category(category), .payout(payout));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 16'd100;
            held_cards <= 5'b0;
            result_category <= 4'b0;
            result_payout <= 12'b0;
        end else begin
            case (state)
                IDLE, RESULT: if (start_deal) begin
                    balance <= balance - 16'd5;
                    held_cards <= 5'b0;
                    result_category <= 4'b0;
                    result_payout <= 12'b0;
                    state <= DEALING;
                end
                DEALING: if (dealer_done) state <= HOLD;
                HOLD: begin
                    held_cards <= hold_mask;
                    if (start_draw) state <= DRAWING;
                end
                DRAWING: if (dealer_done) state <= EVALUATE;
                EVALUATE: begin
                    result_category <= category;
                    result_payout <= payout;
                    balance <= credited_balance[16] ? 16'hffff : credited_balance[15:0];
                    state <= RESULT;
                end
                default: state <= IDLE;
            endcase
        end
    end
    wire _unused = &{dealer_busy, 1'b0};
endmodule
