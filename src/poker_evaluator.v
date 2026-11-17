`default_nettype none

// Multicycle five-card evaluator. Hold cards stable from start through done.
// start is accepted only while idle; done pulses 16 clocks after acceptance.
// Category increases with hand strength:
// 0 loss, 1 jacks+, 2 two pair, 3 trips, 4 straight, 5 flush,
// 6 full house, 7 quads, 8 straight flush, 9 royal flush
module poker_evaluator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [29:0] cards,
    output reg done,
    output reg [3:0] category,
    output reg [11:0] payout
);
    localparam IDLE = 2'd0, SCAN = 2'd1, COMPARE = 2'd2, FINISH = 2'd3;
    reg [1:0] state;
    reg [2:0] card_i, card_j;
    reg [3:0] min_rank, max_rank;
    reg [3:0] pair_count;
    reg valid_hand, flush, wheel, high_pair;

    // Two card selectors feed the same comparators on every cycle.
    wire [5:0] card_a = cards[card_i * 6 +: 6];
    wire [5:0] card_b = cards[card_j * 6 +: 6];
    wire same_rank = card_a[3:0] == card_b[3:0];
    wire straight = pair_count == 4'd0 &&
                    ((max_rank - min_rank == 4'd4) || wheel);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            card_i <= 3'd0;
            card_j <= 3'd1;
            min_rank <= 4'd15;
            max_rank <= 4'd0;
            pair_count <= 4'd0;
            valid_hand <= 1'b1;
            flush <= 1'b1;
            wheel <= 1'b1;
            high_pair <= 1'b0;
            done <= 1'b0;
            category <= 4'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
                    card_i <= 3'd0;
                    card_j <= 3'd1;
                    min_rank <= 4'd15;
                    max_rank <= 4'd0;
                    pair_count <= 4'd0;
                    valid_hand <= 1'b1;
                    flush <= 1'b1;
                    wheel <= 1'b1;
                    high_pair <= 1'b0;
                    state <= SCAN;
                end
                SCAN: begin
                    if (card_a[3:0] < 4'd2 || card_a[3:0] > 4'd14)
                        valid_hand <= 1'b0;
                    if (card_a[5:4] != cards[5:4]) flush <= 1'b0;
                    if (card_a[3:0] < min_rank) min_rank <= card_a[3:0];
                    if (card_a[3:0] > max_rank) max_rank <= card_a[3:0];
                    if (card_a[3:0] != 4'd14 &&
                        (card_a[3:0] < 4'd2 || card_a[3:0] > 4'd5))
                        wheel <= 1'b0;
                    if (card_i == 3'd4) begin
                        card_i <= 3'd0;
                        state <= COMPARE;
                    end else card_i <= card_i + 3'd1;
                end
                COMPARE: begin
                    // Each unordered pair is visited once (ten cycles).
                    // Equal-rank pair counts: pair=1, two pair=2, trips=3,
                    // full house=4, quads=6. Duplicate cards invalidate a hand.
                    if (same_rank) begin
                        pair_count <= pair_count + 4'd1;
                        if (card_a[3:0] >= 4'd11) high_pair <= 1'b1;
                        if (card_a[5:4] == card_b[5:4]) valid_hand <= 1'b0;
                    end
                    if (card_j == 3'd4) begin
                        if (card_i == 3'd3) state <= FINISH;
                        else begin
                            card_i <= card_i + 3'd1;
                            card_j <= card_i + 3'd2;
                        end
                    end else card_j <= card_j + 3'd1;
                end
                FINISH: begin
                    category <= 4'd0;
                    if (valid_hand) begin
                        if (flush && straight)
                            category <= min_rank == 4'd10 ? 4'd9 : 4'd8;
                        else if (pair_count == 4'd6) category <= 4'd7;
                        else if (pair_count == 4'd4) category <= 4'd6;
                        else if (flush) category <= 4'd5;
                        else if (straight) category <= 4'd4;
                        else if (pair_count == 4'd3) category <= 4'd3;
                        else if (pair_count == 4'd2) category <= 4'd2;
                        else if (pair_count == 4'd1 && high_pair) category <= 4'd1;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Decode the registered category without another bank of payout registers.
    always @* begin
        case (category)
            4'd1: payout = 12'd5;
            4'd2: payout = 12'd10;
            4'd3: payout = 12'd15;
            4'd4: payout = 12'd20;
            4'd5: payout = 12'd30;
            4'd6: payout = 12'd45;
            4'd7: payout = 12'd125;
            4'd8: payout = 12'd250;
            4'd9: payout = 12'd4000;
            default: payout = 12'd0;
        endcase
    end
endmodule
