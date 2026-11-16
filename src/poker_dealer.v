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
    output wire [51:0] dealt_mask
);

    reg busy;
    reg [4:0] held;
    reg [2:0] slot;
    reg [63:0] used_cards;
    wire valid_rank = candidate[3:0] >= 4'd2 && candidate[3:0] <= 4'd14;
    // Keep the compact suit * 13 + rank - 2 interface using only fixed wiring.
    // Each 16-bit suit block stores ranks 2..14; ranks 0, 1 and 15 are unused.
    assign dealt_mask = {used_cards[62:50], used_cards[46:34],
                         used_cards[30:18], used_cards[14:2]};
    assign dealer_ready = busy && !held[slot];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cards <= 30'b0;
            used_cards <= 64'b0;
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
                    used_cards <= 64'b0;
                    cards <= 30'b0;
                end
            end else if (busy) begin
                if (held[slot]) begin
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end else if (prng_ready && valid_rank && !used_cards[candidate]) begin
                    cards[slot * 6 +: 6] <= candidate;
                    used_cards[candidate] <= 1'b1;
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end
            end
        end
    end
endmodule
