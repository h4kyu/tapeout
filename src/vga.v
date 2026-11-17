`default_nettype none

module vga (
    input  wire [29:0] cards,
    input  wire [15:0] balance,
    input  wire [4:0]  held_cards,
    input  wire [2:0]  state,
    input  wire [3:0]  hand_category,
    input  wire [3:0]  result_category,
    input  wire [11:0] result_payout,
    input  wire        clk,
    input  wire        rst_n,
    output reg  [1:0]  red,
    output reg  [1:0]  green,
    output reg  [1:0]  blue,
    output wire        hsync,
    output wire        vsync
);

    reg [9:0] x;
    reg [9:0] y;

    assign hsync = !((x >= 10'd656) && (x < 10'd752));
    assign vsync = !((y >= 10'd490) && (y < 10'd492));

    wire visible = (x < 10'd640) && (y < 10'd480);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            if (x == 799) begin
                x <= 0;
                if (y == 524)
                    y <= 0;
                else
                    y <= y + 1;
            end else begin
                x <= x + 1;
            end
        end
    end

    wire card_active;
    wire card_text_active;
    wire [5:0] card_character;
    wire [3:0] card_glyph_x;
    wire [3:0] card_glyph_y;
    wire card_red;

    card_faces hand_cards (
        .x(x), .y(y), .cards(cards), .active(card_active),
        .text_active(card_text_active), .character(card_character),
        .glyph_x(card_glyph_x), .glyph_y(card_glyph_y), .red_suit(card_red)
    );

    wire hold_text_active;
    wire [5:0] hold_character;
    wire [3:0] hold_glyph_x;
    wire [3:0] hold_glyph_y;

    hold_labels card_holds (
        .x(x), .y(y), .held_cards(held_cards),
        .text_active(hold_text_active), .character(hold_character),
        .glyph_x(hold_glyph_x), .glyph_y(hold_glyph_y)
    );

    wire footer_text_active;
    wire [5:0] footer_character;
    wire [4:0] footer_pixel_x;
    wire [4:0] footer_pixel_y;

    credits_bet #(.MULTIPLE_OF_FIVE(1)) footer (
        .clk(clk), .rst_n(rst_n), .x(x), .y(y), .balance(balance),
        .state(state), .payout(result_payout),
        .text_active(footer_text_active), .character(footer_character),
        .glyph_x(), .glyph_y(), .pixel_x(footer_pixel_x), .pixel_y(footer_pixel_y)
    );

    wire hand_text_active;
    wire hand_yellow;
    wire [3:0] hand_text_row;
    wire [3:0] hand_text_column;
    wire [4:0] hand_pixel_x;
    wire [4:0] hand_pixel_y;

    hand_message current_hand (
        .x(x), .y(y), .state(state), .hand_category(hand_category),
        .result_category(result_category), .text_active(hand_text_active),
        .yellow(hand_yellow), .text_row(hand_text_row),
        .text_column(hand_text_column), .glyph_x(), .glyph_y(), .pixel_x(hand_pixel_x), .pixel_y(hand_pixel_y)
    );

    // Reuse the baseline hand-name character lookup; numbers are unused here.
    wire [5:0] table_character;
    payout_characters table_words (
        .numbers(1'b0),
        .text_row(hand_text_row),
        .column(hand_text_column),
        .character(table_character)
    );


    function [3:0] scale20;
        input [4:0] pixel;
        begin
            case (pixel)
                5'd0, 5'd1: scale20 = 4'd0;
                5'd2, 5'd3: scale20 = 4'd1;
                5'd4: scale20 = 4'd2;
                5'd5, 5'd6: scale20 = 4'd3;
                5'd7, 5'd8: scale20 = 4'd4;
                5'd9: scale20 = 4'd5;
                5'd10, 5'd11: scale20 = 4'd6;
                5'd12, 5'd13: scale20 = 4'd7;
                5'd14: scale20 = 4'd8;
                5'd15, 5'd16: scale20 = 4'd9;
                5'd17, 5'd18: scale20 = 4'd10;
                5'd19: scale20 = 4'd11;
                default: scale20 = 4'd0;
            endcase
        end
    endfunction
    wire [3:0] shared20_x=scale20(hand_pixel_x);
    wire [3:0] shared20_y=scale20(hand_pixel_y);

    // Footer results share its native-size text request. All these text regions
    // are spatially separate from the card and hand-name regions.
    wire footer_zone = y >= 416;
    wire card_zone = y >= 261;
    wire hold_zone = y >= 246;
    wire [5:0] font_character = footer_zone ? footer_character :
                               card_zone ? card_character :
                               hold_zone ? hold_character : table_character;
    wire [3:0] font_row = footer_zone ? footer_pixel_y[3:0] :
                         card_zone ? card_glyph_y :
                         hold_zone ? hold_glyph_y : shared20_y;
    wire [3:0] font_column = footer_zone ? footer_pixel_x[3:0] :
                            card_zone ? card_glyph_x :
                            hold_zone ? hold_glyph_x : shared20_x;
    wire font_active = (footer_text_active || hold_text_active ||
                        hand_text_active || card_text_active);
    wire font_yellow = footer_text_active || (hand_text_active && hand_yellow);
    // The text regions are vertically disjoint, and active glyph coordinates
    // are already bounded to 0..11 by every producer.
    wire font_card = card_text_active;
    wire [11:0] font_pixels;
    wire text_pixel = font_active && font_pixels[4'd11 - font_column];

    font_rom text_font (
        .character(font_character), .row(font_row), .pixels(font_pixels)
    );

    always @* begin
        red   = 2'b00;
        green = 2'b00;
        blue  = 2'b00;

        if (visible) begin
            // Green background
            green = 2'b10;

            // Card geometry is owned by card_faces.v, even before a deal.
            if (card_active) begin
                red   = 2'b11;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Text is drawn last so glyph pixels overwrite the table panels.
            if (text_pixel) begin
                red   = font_card ? (card_red ? 2'b11 : 2'b00) : 2'b11;
                green = font_card ? 2'b00 : 2'b11;
                blue  = font_card ? 2'b00 : (font_yellow ? 2'b00 : 2'b11);
            end
        end
    end

endmodule
