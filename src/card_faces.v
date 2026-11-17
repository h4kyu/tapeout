`default_nettype none

// Card rectangles, rank indices, center pips, and face-card glyph requests. One card is selected by the
// current pixel; all five cards share the sole font ROM in vga.v.
module card_faces (
    input wire [9:0] x,
    input wire [9:0] y,
    input wire [29:0] cards,
    output reg active,
    output reg text_active,
    output reg [5:0] character,
    output wire [3:0] glyph_x,
    output wire [3:0] glyph_y,
    output wire red_suit
);
    reg [5:0] selected_card;
    reg [6:0] card_x;
    reg [7:0] card_y;
    reg [2:0] slot;
    reg [9:0] card_left; // Select the origin before subtracting local x.
    always @* begin
        active = 1'b0;
        selected_card = 6'd0;
        card_x = 0;
        card_y = 0;
        slot = 3'd0;
        card_left = 10'd23;
        if (x >= 23 && x < 617 && y >= 261 && y < 415) begin
            if (x >= 507) begin slot = 3'd4; card_left = 10'd507; end
            else if (x >= 386) begin slot = 3'd3; card_left = 10'd386; end
            else if (x >= 265) begin slot = 3'd2; card_left = 10'd265; end
            else if (x >= 144) begin slot = 3'd1; card_left = 10'd144; end
            if (x < card_left + 10'd110) begin
                active = 1'b1;
                card_x = x - card_left;
                card_y = y - 261;
                case (slot)
                    3'd0: selected_card = cards[5:0];
                    3'd1: selected_card = cards[11:6];
                    3'd2: selected_card = cards[17:12];
                    3'd3: selected_card = cards[23:18];
                    3'd4: selected_card = cards[29:24];
                    default: selected_card = 6'd0;
                endcase
            end
        end
    end

    wire [3:0] rank = selected_card[3:0];
    wire valid_card = (rank >= 4'd2 && rank <= 4'd14);
    // Suit encoding is C/D/H/S = 0/1/2/3: only 1 and 2 are red.
    assign red_suit = selected_card[5] ^ selected_card[4];

    function [5:0] rank_character;
        input [3:0] card_rank;
        begin
            case (card_rank)
                4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9:
                    rank_character = 6'd1 + {2'b00, card_rank};
                4'd11: rank_character = 6'd20; // J
                4'd12: rank_character = 6'd27; // Q
                4'd13: rank_character = 6'd21; // K
                4'd14: rank_character = 6'd11; // A
                default: rank_character = 6'd0;
            endcase
        end
    endfunction

    reg [6:0] center_rows; // Center and outer columns share the same suit font.
    reg [6:0] outer_rows; // Left and right occupancy are identical.
    always @* begin
        case (rank)
            4'd2: begin center_rows = 7'b1000001; outer_rows = 7'b0000000; end
            4'd3: begin center_rows = 7'b1001001; outer_rows = 7'b0000000; end
            4'd4: begin center_rows = 7'b0000000; outer_rows = 7'b1000001; end
            4'd5: begin center_rows = 7'b0001000; outer_rows = 7'b1000001; end
            4'd6: begin center_rows = 7'b0000000; outer_rows = 7'b1001001; end
            4'd7: begin center_rows = 7'b0000010; outer_rows = 7'b1001001; end
            4'd8: begin center_rows = 7'b0100010; outer_rows = 7'b1001001; end
            4'd9: begin center_rows = 7'b0001000; outer_rows = 7'b1010101; end
            4'd10: begin center_rows = 7'b0100010; outer_rows = 7'b1010101; end
            default: begin center_rows = 7'd0; outer_rows = 7'd0; end
        endcase
    end
    wire pip_present = (pip_column == 1) ? center_rows[pip_row] : outer_rows[pip_row];

    reg [2:0] pip_row;
    reg [1:0] pip_column;
    reg [6:0] pip_x;
    reg [6:0] pip_y;
    reg pip_row_valid; // Explicit validity avoids signed sentinel indices.
    reg pip_column_valid;
    integer grid_row;
    always @* begin
        pip_column = 0;
        pip_column_valid = 1'b0;
        pip_row = 0;
        pip_row_valid = 1'b0;
        pip_x = 0;
        pip_y = 0;
        if (card_x >= 27 && card_x < 39) begin
            pip_column = 0;
            pip_column_valid = 1'b1;
            pip_x = 27;
        end else if (card_x >= 49 && card_x < 61) begin
            pip_column = 1;
            pip_column_valid = 1'b1;
            pip_x = 49;
        end else if (card_x >= 71 && card_x < 83) begin
            pip_column = 2;
            pip_column_valid = 1'b1;
            pip_x = 71;
        end
        for (grid_row = 0; grid_row < 7; grid_row = grid_row + 1) begin
            if (card_y >= 32 + 14 * grid_row && card_y < 44 + 14 * grid_row) begin
                pip_row = grid_row;
                pip_row_valid = 1'b1;
                pip_y = 32 + 14 * grid_row;
            end
        end
    end

    reg [6:0] index_x;
    reg [7:0] index_y;
    reg [3:0] x_offset;
    reg [3:0] y_offset;
    always @* begin
        text_active = 1'b0;
        character = 6'd0;
        x_offset = 0;
        y_offset = 0;
        index_x = card_x;
        index_y = card_y;

        // Map the bottom half through a 180-degree rotation. The same corner
        // layout then selects both the top-left and bottom-right indices.
        if (card_y >= 77) begin
            index_x = 109 - card_x;
            index_y = 153 - card_y;
        end

        if (active && valid_card) begin
            if (index_y >= 8 && index_y < 20) begin
                if (rank == 4'd10 && index_x >= 5 && index_x < 29) begin
                    text_active = 1'b1;
                    if (index_x < 17) begin
                        character = 6'd2; // 1
                        x_offset = index_x - 5;
                    end else begin
                        character = 6'd1; // 0
                        x_offset = index_x - 17;
                    end
                    y_offset = index_y - 8;
                end else if (rank != 4'd10 && index_x >= 11 && index_x < 23) begin
                    text_active = 1'b1;
                    character = rank_character(rank);
                    x_offset = index_x - 11;
                    y_offset = index_y - 8;
                end
            end

            // Face cards use corner suits and a centered 48px rank portrait.
            // Numbered cards omit corner suits so their pips count exactly.
            if (rank >= 4'd11 && rank <= 4'd13 &&
                index_x >= 11 && index_x < 23 && index_y >= 24 && index_y < 36) begin
                text_active = 1'b1;
                character = 6'd37 + {4'b0000, selected_card[5:4]};
                x_offset = index_x - 11;
                y_offset = index_y - 24;
            end else if (rank >= 4'd11 && rank <= 4'd13 &&
                         card_x >= 31 && card_x < 79 && card_y >= 53 && card_y < 101) begin
                text_active = 1'b1;
                character = rank_character(rank);
                x_offset = (card_x - 31) >> 2;
                y_offset = (card_y - 53) >> 2;
            end else if (rank == 4'd14 && card_x >= 49 && card_x < 61 &&
                         card_y >= 71 && card_y < 83) begin
                // Ace has one ordinary 12px pip, like the numbered cards.
                text_active = 1'b1;
                character = 6'd37 + {4'b0000, selected_card[5:4]};
                x_offset = card_x - 49;
                y_offset = card_y - 71;
            end

            // Decode the pip grid once, then select its rank-specific mask bit.
            if (rank >= 4'd2 && rank <= 4'd10 && pip_row_valid && pip_column_valid &&
                pip_present) begin
                text_active = 1'b1;
                character = 6'd37 + {4'b0000, selected_card[5:4]};
                x_offset = card_x - pip_x;
                y_offset = card_y - pip_y;
                if (pip_row > 3) begin
                    x_offset = 11 - x_offset;
                    y_offset = 11 - y_offset;
                end
            end
        end
    end

    assign glyph_x = x_offset[3:0];
    assign glyph_y = y_offset[3:0];
endmodule
