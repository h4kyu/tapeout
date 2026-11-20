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
    wire [6:0] column_x;
    wire [2:0] slot;
    wire column_active;
    card_column column_geometry(.x(x), .local_x(column_x), .slot(slot), .active(column_active));
    wire [6:0] card_x = column_x;
    wire [7:0] card_y = y[7:0] - 8'd5; // (y - 261) modulo 256.
    always @* begin
        active = column_active && column_x < 7'd110 && y >= 261 && y < 415;
        case (slot)
            0: selected_card=cards[5:0];
            1: selected_card=cards[11:6];
            2: selected_card=cards[17:12];
            3: selected_card=cards[23:18];
            4: selected_card=cards[29:24];
            default: selected_card=0;
        endcase
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

    wire ten = rank == 10;
    wire rank_area = y >= 304 && y < 328 && (ten ? x[6:0]>=40 && x[6:0]<88 : x[6:0]>=52 && x[6:0]<76);
    wire suit_area = y >= 352 && y < 376 && x[6:0]>=52 && x[6:0]<76;
    wire first_digit = x[6:0] < 64;
    always @* begin
        text_active = active && valid_card && (rank_area || suit_area);
        character = suit_area ? 37 + selected_card[5:4] :
                    ten ? (first_digit ? 2 : 1) : rank_character(rank);
    end
    assign glyph_x = ten && rank_area ? (first_digit ? x[4:1]-4'd4 : x[4:1]) : x[4:1]-4'd10;
    assign glyph_y = suit_area ? y[4:1] : y[4:1]-4'd8;
endmodule

// Identical instances in card and HOLD renderers share after flattening.
module card_column(input wire [9:0] x, output wire [6:0] local_x,
                   output reg [2:0] slot, output wire active);
    always @* slot=x[9:7];
    assign local_x=x[6:0]-7'd9;
    assign active=x<640;
endmodule
