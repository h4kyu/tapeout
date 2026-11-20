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

    // Center names on 16-pixel slots. Odd lengths start halfway across a slot.
    wire [8:0] rel_x = x[8:0] - (9'd320 - {2'b0,character_count,3'b0});
    wire in_name = x < 512 && rel_x[8:4] < character_count;
    always @* begin
        text_active=complete_hand && qualifying_hand && y>=216 && y<228 && in_name && rel_x[3:0]<12;
        text_column=rel_x[7:4];
    end
    assign pixel_x={1'b0,rel_x[3:0]};
    assign pixel_y={1'b0,y[3:0]-4'd8};
    assign glyph_x=pixel_x[3:0];
    assign glyph_y=pixel_y[3:0];
endmodule
