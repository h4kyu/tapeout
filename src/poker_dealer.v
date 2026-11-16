`default_nettype none

// cards as {suit[1:0], rank[3:0]}, rank 2..14
// candidate is consumed on every prng_ready && dealer_ready edge
module poker_dealer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire draw_mode,
    input wire [4:0] hold_mask,
    input wire [5:0] candidate,
    input wire prng_ready,
    output wire dealer_ready,
    output reg done,
    output reg [29:0] cards,
    output reg [51:0] dealt_mask
);

    reg busy;
    reg [4:0] held;
    reg [2:0] slot;
    // Keep both the initial hand and replacements, including discarded cards.
    reg [5:0] used_cards [0:9];
    reg [3:0] used_count;
    reg candidate_used;
    integer i;
    wire valid_rank = candidate[3:0] >= 4'd2 && candidate[3:0] <= 4'd14;
    assign dealer_ready = busy && !held[slot];

    always @* begin
        candidate_used = 1'b0;
        // Preserve the inspection interface without storing a second mask.
        // This decode is removed when dealt_mask is unconnected at the top level.
        dealt_mask = 52'b0;
        for (i = 0; i < 10; i = i + 1) begin
            if (i < used_count) begin
                if (candidate == used_cards[i]) candidate_used = 1'b1;
                dealt_mask[used_cards[i][5:4] * 13 + used_cards[i][3:0] - 2] = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cards <= 30'b0;
            used_count <= 4'b0;
            busy <= 1'b0;
            done <= 1'b0;
            held <= 5'b0;
            slot <= 3'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                slot <= 3'd0;
                held <= draw_mode ? hold_mask : 5'b0;
                if (!draw_mode) begin
                    // Entries outside used_count are ignored, so storage need not clear.
                    used_count <= 4'b0;
                    cards <= 30'b0;
                end
            end else if (busy) begin
                if (held[slot]) begin
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end else if (prng_ready && valid_rank && !candidate_used && used_count < 4'd10) begin
                    cards[slot * 6 +: 6] <= candidate;
                    used_cards[used_count] <= candidate;
                    used_count <= used_count + 4'd1;
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end
            end
        end
    end
endmodule
