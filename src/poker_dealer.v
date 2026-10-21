`default_nettype none

// cards as {suit[1:0], rank[3:0]}, rank 2..14
// candidate is consumed on every candidate_valid && candidate_ready edge
module poker_dealer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire draw_mode,
    input wire [4:0] hold_mask,
    input wire [5:0] candidate,
    input wire candidate_valid,
    output wire candidate_ready,
    output reg busy,
    output reg done,
    output reg [29:0] cards,
    output reg [51:0] dealt_mask
);

    reg [4:0] held;
    reg [2:0] slot;
    wire valid_rank = candidate[3:0] >= 4'd2 && candidate[3:0] <= 4'd14;
    wire [5:0] card_index = {4'b0, candidate[5:4]} * 6'd13
                           + {2'b0, candidate[3:0]} - 6'd2;
    assign candidate_ready = busy && !held[slot];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cards <= 30'b0;
            dealt_mask <= 52'b0;
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
                    dealt_mask <= 52'b0;
                    cards <= 30'b0;
                end
            end else if (busy) begin
                if (held[slot]) begin
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end else if (candidate_valid && valid_rank) begin
                    if (!dealt_mask[card_index]) begin
                        cards[slot * 6 +: 6] <= candidate;
                        dealt_mask[card_index] <= 1'b1;
                        if (slot == 3'd4) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else slot <= slot + 3'd1;
                    end
                end
            end
        end
    end
endmodule
