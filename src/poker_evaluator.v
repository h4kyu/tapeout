`default_nettype none

// combinational five-card evaluator. Category increases with hand strength:
// 0 loss, 1 jacks+, 2 two pair, 3 trips, 4 straight, 5 flush,
// 6 full house, 7 quads, 8 straight flush, 9 royal flush
module poker_evaluator #(parameter DEALER_VALIDATED=0) (
    input wire [29:0] cards,
    output reg [3:0] category,
    output reg [11:0] payout
);
    wire [3:0] rank [0:4];
    wire [1:0] suit [0:4];
    wire [4:0] rank_equal [0:4];
    reg [12:0] ranks;
    reg valid_hand, flush, straight;
    integer i, j, k;
    reg pair_found, trips_found, quads_found, two_pairs_found;
    reg high_pair;

    genvar a, b;
    generate
        for (a = 0; a < 5; a = a + 1) begin : card_fields
            assign rank[a] = cards[a * 6 +: 4];
            assign suit[a] = cards[a * 6 + 4 +: 2];
            for (b = 0; b < 5; b = b + 1) begin : comparisons
                // Only the ten unique pairs need rank comparators.
                if (a < b) begin : unique_pair
                    assign rank_equal[a][b] = (rank[a] == rank[b]);
                end else begin : unused_pair
                    assign rank_equal[a][b] = 1'b0;
                end
            end
        end
    endgenerate

    always @* begin
        ranks = 13'b0;
        valid_hand = 1'b1;
        flush = 1'b1;
        straight = 1'b0;
        pair_found = 1'b0;
        trips_found = 1'b0;
        quads_found = 1'b0;
        two_pairs_found = 1'b0;
        high_pair = 1'b0;
        for (k=0; k<13; k=k+1)
            ranks[k] = (rank[0] == k+2) || (rank[1] == k+2) ||
                       (rank[2] == k+2) || (rank[3] == k+2) || (rank[4] == k+2);
        for (i = 0; i < 5; i = i + 1) begin
            if (!DEALER_VALIDATED && (rank[i] < 2 || rank[i] > 14)) valid_hand = 1'b0;

            if (suit[i] != cards[5:4]) flush = 1'b0;
        end
        for (i = 0; i < 5; i = i + 1) begin
            for (j = i + 1; j < 5; j = j + 1) begin
                if (rank_equal[i][j]) begin
                    pair_found = 1'b1;
                    if (rank[i] >= 11) high_pair = 1'b1;
                    if (!DEALER_VALIDATED && suit[i] == suit[j]) valid_hand = 1'b0;
                end
            end
        end
        trips_found = trips_found | (rank_equal[0][1] & rank_equal[0][2]);
        trips_found = trips_found | (rank_equal[0][1] & rank_equal[0][3]);
        trips_found = trips_found | (rank_equal[0][1] & rank_equal[0][4]);
        trips_found = trips_found | (rank_equal[0][2] & rank_equal[0][3]);
        trips_found = trips_found | (rank_equal[0][2] & rank_equal[0][4]);
        trips_found = trips_found | (rank_equal[0][3] & rank_equal[0][4]);
        trips_found = trips_found | (rank_equal[1][2] & rank_equal[1][3]);
        trips_found = trips_found | (rank_equal[1][2] & rank_equal[1][4]);
        trips_found = trips_found | (rank_equal[1][3] & rank_equal[1][4]);
        trips_found = trips_found | (rank_equal[2][3] & rank_equal[2][4]);
        quads_found = quads_found | (rank_equal[0][1] & rank_equal[0][2] & rank_equal[0][3]);
        two_pairs_found = two_pairs_found | (rank_equal[0][1] & rank_equal[2][3]);
        two_pairs_found = two_pairs_found | (rank_equal[0][2] & rank_equal[1][3]);
        two_pairs_found = two_pairs_found | (rank_equal[0][3] & rank_equal[1][2]);
        quads_found = quads_found | (rank_equal[0][1] & rank_equal[0][2] & rank_equal[0][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][1] & rank_equal[2][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][2] & rank_equal[1][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][4] & rank_equal[1][2]);
        quads_found = quads_found | (rank_equal[0][1] & rank_equal[0][3] & rank_equal[0][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][1] & rank_equal[3][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][3] & rank_equal[1][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][4] & rank_equal[1][3]);
        quads_found = quads_found | (rank_equal[0][2] & rank_equal[0][3] & rank_equal[0][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][2] & rank_equal[3][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][3] & rank_equal[2][4]);
        two_pairs_found = two_pairs_found | (rank_equal[0][4] & rank_equal[2][3]);
        quads_found = quads_found | (rank_equal[1][2] & rank_equal[1][3] & rank_equal[1][4]);
        two_pairs_found = two_pairs_found | (rank_equal[1][2] & rank_equal[3][4]);
        two_pairs_found = two_pairs_found | (rank_equal[1][3] & rank_equal[2][4]);
        two_pairs_found = two_pairs_found | (rank_equal[1][4] & rank_equal[2][3]);
        for (k = 0; k < 9; k = k + 1)
            if (ranks[k +:5] == 5'b11111) straight = 1'b1;
        // A,2,3,4,5: ace is low only for this straight.
        if (ranks[12] && ranks[3:0] == 4'b1111) straight = 1'b1;

        category = 4'd0;
        payout = 12'd0;
        if (valid_hand) begin
            if (flush && ranks[12:8] == 5'b11111) begin
                category = 4'd9; payout = 12'd4000;
            end else if (flush && straight) begin
                category = 4'd8; payout = 12'd250;
            end else if (quads_found) begin
                category = 4'd7; payout = 12'd125;
            end else if (trips_found && two_pairs_found) begin
                category = 4'd6; payout = 12'd45;
            end else if (flush) begin
                category = 4'd5; payout = 12'd30;
            end else if (straight) begin
                category = 4'd4; payout = 12'd20;
            end else if (trips_found) begin
                category = 4'd3; payout = 12'd15;
            end else if (two_pairs_found) begin
                category = 4'd2; payout = 12'd10;
            end else if (pair_found && high_pair) begin
                category = 4'd1; payout = 12'd5;
            end
        end
    end
endmodule
