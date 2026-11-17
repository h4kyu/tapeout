`default_nettype none

// Footer glyph requests. Uses the shared font ROM in vga.v; no ROM here.
// BET, credits, and result share native 12-pixel cells with yellow text.
module credits_bet (
    input wire [2:0] state,
    input wire [11:0] payout,
    input  wire clk,
    input  wire rst_n,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [15:0] balance,
    output reg text_active,
    output reg [5:0] character,
    output wire [3:0] glyph_x,
    output wire [4:0] pixel_x,
    output wire [4:0] pixel_y,
    output wire [3:0] glyph_y
);
    // The core has nine fixed awards. A small constant decoder is sufficient;
    // keep this list aligned with poker_evaluator's fixed-wager pay table.
    reg [15:0] payout_digits;
    reg winning_payout;
    always @* begin
        case (payout)
            12'd5:    begin payout_digits = 16'h0005; winning_payout = 1'b1; end
            12'd10:   begin payout_digits = 16'h0010; winning_payout = 1'b1; end
            12'd15:   begin payout_digits = 16'h0015; winning_payout = 1'b1; end
            12'd20:   begin payout_digits = 16'h0020; winning_payout = 1'b1; end
            12'd30:   begin payout_digits = 16'h0030; winning_payout = 1'b1; end
            12'd45:   begin payout_digits = 16'h0045; winning_payout = 1'b1; end
            12'd125:  begin payout_digits = 16'h0125; winning_payout = 1'b1; end
            12'd250:  begin payout_digits = 16'h0250; winning_payout = 1'b1; end
            12'd4000: begin payout_digits = 16'h4000; winning_payout = 1'b1; end
            default:  begin payout_digits = 16'h0000; winning_payout = 1'b0; end
        endcase
    end

    wire result_ready=(state == 3'd5 && (payout == 0 || winning_payout));

    // Serial double-dabble: five decimal digits, one binary bit per clock.
    // Commit all digits together after 16 steps so no partial number is drawn.
    reg [19:0] displayed_digits;
    // The input value sampled at conversion start also detects subsequent
    // changes after completion; a second saved balance register is unnecessary.
    reg [15:0] sampled_balance;
    reg [19:0] decimal_shift;
    reg [4:0] bits_left;
    wire busy=(bits_left != 5'd0);
    reg [19:0] adjusted_digits;
    integer digit;

    always @* begin
        adjusted_digits = decimal_shift;
        for (digit = 0; digit < 5; digit = digit + 1) begin
            if (decimal_shift[digit * 4 +: 4] >= 4'd5)
                adjusted_digits[digit * 4 +: 4] = decimal_shift[digit * 4 +: 4] + 4'd3;
        end
    end

    wire [19:0] next_digits = {adjusted_digits[18:0], sampled_balance[bits_left[3:0]-4'd1]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            displayed_digits <= 20'h00100;
            sampled_balance <= 16'd100;

            decimal_shift <= 20'd0;
            bits_left <= 5'd0;
        end else if (busy) begin
            decimal_shift <= next_digits;

            if (bits_left == 5'd1) begin
                displayed_digits <= next_digits;
                bits_left <= 5'd0;
            end else begin
                bits_left <= bits_left - 5'd1;
            end
        end else if (balance != sampled_balance) begin
            sampled_balance <= balance;

            decimal_shift <= 20'd0;
            bits_left <= 5'd16;
        end
    end

    function [5:0] credits_character;
        input [2:0] column;
        begin
            case (column)
                3'd0: credits_character = 6'd13; // C
                3'd1: credits_character = 6'd28; // R
                3'd2: credits_character = 6'd15; // E
                3'd3: credits_character = 6'd14; // D
                3'd4: credits_character = 6'd19; // I
                3'd5: credits_character = 6'd30; // T
                3'd6: credits_character = 6'd29; // S
                default: credits_character = 6'd0;
            endcase
        end
    endfunction

    function [5:0] bet_character;
        input [2:0] column;
        begin
            case (column)
                3'd0: bet_character = 6'd12; // B
                3'd1: bet_character = 6'd15; // E
                3'd2: bet_character = 6'd30; // T
                3'd4: bet_character = 6'd6;  // 5
                default: bet_character = 6'd0;
            endcase
        end
    endfunction

    // Fixed five-digit balance and nine-cell result field keep positions constant.
    reg [3:0] column;
    reg [4:0] x_offset;
    reg [4:0] y_offset;
    reg [7:0] local_x;
    reg [7:0] cell_left;
    reg [2:0] region;

    always @* begin
        text_active = 1'b0;
        character = 6'd0;
        x_offset = 0;
        y_offset = 0;
        local_x = 0;
        region = 3'd0;
        // Choose a text region before decoding the character position.
        if (y >= 446 && y < 458) begin
            if (x >= 25 && x < 85) begin
                region = 3'd1;
                local_x = x - 25;
            end else if (x >= 10'd459 && x < 10'd543) begin
                region = 3'd2;
                local_x = x - 10'd459;
            end else if (x >= 555 && x < 615) begin
                region = 3'd3;
                local_x = x - 555;
            end else if (result_ready && x>=266 && x<374) begin
                region=3'd4;
                local_x=x-266;
            end
        end
        // All regions share this cell decoder and glyph-offset subtractor.
        column = 0;
        cell_left = 0;
        if (local_x >= 96) begin column=8; cell_left=96; end
        else if (local_x >= 84) begin column=7; cell_left=84; end
        else if (local_x >= 72) begin column = 6; cell_left = 72; end
        else if (local_x >= 60) begin column = 5; cell_left = 60; end
        else if (local_x >= 48) begin column = 4; cell_left = 48; end
        else if (local_x >= 36) begin column = 3; cell_left = 36; end
        else if (local_x >= 24) begin column = 2; cell_left = 24; end
        else if (local_x >= 12) begin column = 1; cell_left = 12; end
        if (region != 3'd0) begin
            text_active = 1'b1;
            x_offset = local_x - cell_left;
            y_offset = y - 446;
            case (region)
                2'd1: character = bet_character(column[2:0]);
                2'd2: character = credits_character(column[2:0]);
                2'd3: character = 6'd1 + {2'b00, displayed_digits[(4'd4 - column) * 4 +: 4]};
                3'd4: begin
                    if (payout == 0) begin
                        case (column)
                            0: character = 6'd17; // G
                            1: character = 6'd11; // A
                            2: character = 6'd23; // M
                            3: character = 6'd15; // E
                            4: character = 6'd0;  // Space
                            5: character = 6'd25; // O
                            6: character = 6'd32; // V
                            7: character = 6'd15; // E
                            8: character = 6'd28; // R
                            default: character = 6'd0;
                        endcase
                    end else begin
                        case (column)
                            0: character = 6'd33; // W
                            1: character = 6'd19; // I
                            2: character = 6'd24; // N
                            3: character = 6'd0;  // Space
                            4: character = 6'd1 + {2'b00, payout_digits[15:12]};
                            5: character = 6'd1 + {2'b00, payout_digits[11:8]};
                            6: character = 6'd1 + {2'b00, payout_digits[7:4]};
                            7: character = 6'd1 + {2'b00, payout_digits[3:0]};
                            default: character = 6'd0;
                        endcase
                    end
                end
                default: character = 6'd0;
            endcase
        end
    end

    assign pixel_x=x_offset;
    assign pixel_y=y_offset;
    assign glyph_x = x_offset[3:0];
    assign glyph_y = y_offset[3:0];
endmodule
