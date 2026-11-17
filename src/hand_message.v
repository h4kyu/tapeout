`default_nettype none

// Center the qualifying hand name in the Figma message area above the cards.
// Returns a request into payout_characters, not a second name or font ROM.
module hand_message (
    input wire [9:0] x,
    input wire [9:0] y,
    input wire [2:0] state,
    input wire [3:0] hand_category,
    input wire [3:0] result_category,
    output reg text_active,
    output wire yellow,
    output wire [3:0] text_row,
    output reg [3:0] text_column,
    output wire [3:0] glyph_x,
    output wire [4:0] pixel_x,
    output wire [4:0] pixel_y,
    output wire [3:0] glyph_y
);
    // HOLD uses the live evaluator. EVALUATE has complete drawn cards; RESULT
    // uses the latched award category. Never show partial dealing/drawing hands.
    wire [3:0] category = (state == 3'd5) ? result_category : hand_category;
    wire complete_hand = (state == 3'd2 || state == 3'd4 || state == 3'd5);
    wire qualifying_hand = (category >= 4'd1 && category <= 4'd9);
    assign yellow = (state == 3'd4 || state == 3'd5);
    assign text_row = qualifying_hand ? 4'd9 - category : 4'd0;

    reg [3:0] character_count;
    always @* begin
        case (category)
            4'd9: character_count = 4'd11; // ROYAL FLUSH
            4'd8: character_count = 4'd14; // STRAIGHT FLUSH
            4'd7: character_count = 4'd14; // FOUR OF A KIND
            4'd6: character_count = 4'd10; // FULL HOUSE
            4'd5: character_count = 4'd5;  // FLUSH
            4'd4: character_count = 4'd8;  // STRAIGHT
            4'd3: character_count = 4'd15; // THREE OF A KIND
            4'd2: character_count = 4'd8;  // TWO PAIR
            4'd1: character_count = 4'd15; // JACKS OR BETTER
            default: character_count = 4'd0;
        endcase
    end

    // The six centered origins are constants; avoid recomputing the origin
    // from the character count in every character-position comparison.
    reg [8:0] centered_left;
    always @* begin
        case (category)
            4'd1, 4'd3: centered_left = 9'd170;
            4'd7, 4'd8: centered_left = 9'd180;
            4'd9: centered_left = 9'd210;
            4'd6: centered_left = 9'd220;
            4'd2, 4'd4: centered_left = 9'd240;
            4'd5: centered_left = 9'd270;
            default: centered_left = 9'd320;
        endcase
    end

    function [3:0] font_coordinate;
        input [4:0] pixel;
        begin
            case (pixel)
                5'd0, 5'd1: font_coordinate = 4'd0;
                5'd2, 5'd3: font_coordinate = 4'd1;
                5'd4: font_coordinate = 4'd2;
                5'd5, 5'd6: font_coordinate = 4'd3;
                5'd7, 5'd8: font_coordinate = 4'd4;
                5'd9: font_coordinate = 4'd5;
                5'd10, 5'd11: font_coordinate = 4'd6;
                5'd12, 5'd13: font_coordinate = 4'd7;
                5'd14: font_coordinate = 4'd8;
                5'd15, 5'd16: font_coordinate = 4'd9;
                5'd17, 5'd18: font_coordinate = 4'd10;
                5'd19: font_coordinate = 4'd11;
                default: font_coordinate = 4'd0;
            endcase
        end
    endfunction

    // Normalize once to the message's local coordinate. All 15 character
    // slots share this range check, cell decoder, and glyph-offset subtractor.
    reg [8:0] left;
    reg [3:0] column;
    reg [4:0] x_offset;
    reg [4:0] y_offset;
    reg [8:0] local_x;
    reg [8:0] cell_left;
    always @* begin
        text_active = 1'b0;
        text_column = 4'd0;
        left = centered_left;
        column = 0;
        x_offset = 0;
        y_offset = 0;
        local_x = 0;
        cell_left = 0;
        if (complete_hand && qualifying_hand && y >= 213 && y < 233 &&
            x >= left && x < {1'b0,left} + character_count * 10'd20) begin
            text_active = 1'b1;
            local_x = x - left;
            column = local_x / 9'd20;
            text_column = column;
            x_offset = local_x % 9'd20;
            y_offset = y - 213;
        end
    end

    assign pixel_x=x_offset;
    assign pixel_y=y_offset;
    assign glyph_x = font_coordinate(x_offset[4:0]);
    assign glyph_y = font_coordinate(y_offset[4:0]);
endmodule
