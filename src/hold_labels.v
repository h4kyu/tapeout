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

    wire [6:0] column_x;
    wire [2:0] slot;
    wire column_active;
    card_column column_geometry(.x(x), .local_x(column_x), .slot(slot), .active(column_active));
    wire selected = column_active && column_x>=28 && column_x<82 && held_cards[slot];
    reg [5:0] local_x;
    reg [5:0] cell_left;
    reg [1:0] column;
    reg [3:0] x_offset;
    reg [3:0] y_offset;
    always @* begin
        text_active = 1'b0;
        character = 6'd0;
        local_x = 6'd0;
        cell_left = 6'd0;
        column = 2'd0;
        x_offset = 4'd0;
        y_offset = 4'd0;
        if (selected && y >= 246 && y < 258) begin
            local_x = column_x[5:0]-6'd28;
            if (local_x >= 42) begin column=2'd3; cell_left=6'd42; end
            else if (local_x >= 28) begin column=2'd2; cell_left=6'd28; end
            else if (local_x >= 14) begin column=2'd1; cell_left=6'd14; end
            if (local_x-cell_left < 6'd12) begin
                text_active=1'b1;
                character=hold_character(column);
                x_offset=local_x-cell_left;
                y_offset=y-246;
            end
        end
    end

    assign glyph_x = x_offset[3:0];
    assign glyph_y = y_offset[3:0];
endmodule
