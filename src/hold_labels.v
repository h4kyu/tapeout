`default_nettype none

// Center a 54-pixel HOLD label over each selected 110-pixel card.
// Labels use 12x12 glyphs with two pixels between characters, at y=246.
// This module requests glyphs; the shared font ROM remains in vga.v.
module hold_labels (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [4:0] held_cards,
    output reg text_active,
    output reg [5:0] character,
    output wire [3:0] glyph_x,
    output wire [3:0] glyph_y
);
    function [5:0] hold_character;
        input [1:0] column;
        begin
            case (column)
                2'd0: hold_character = 6'd18; // H
                2'd1: hold_character = 6'd25; // O
                2'd2: hold_character = 6'd22; // L
                2'd3: hold_character = 6'd14; // D
                default: hold_character = 6'd0;
            endcase
        end
    endfunction

    always @* begin
        text_active = y>=246 && y<258 && x<640 && x[6:0]>=32 && x[6:0]<96
                    && x[3:0]<12 && held_cards[x[9:7]];
        character=hold_character(x[5:4]-2'd2);
    end
    assign glyph_x=x[3:0];
    assign glyph_y=y-246;
endmodule
