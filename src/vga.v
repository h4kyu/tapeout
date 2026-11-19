`default_nettype none

module vga #(parameter EXTERNAL_DIGITS=0) (
    input wire [19:0] credit_digits,
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

    wire h_raw = !((x >= 10'd656) && (x < 10'd752));
    wire v_raw = !((y >= 10'd490) && (y < 10'd492));

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

    credits_bet #(.MULTIPLE_OF_FIVE(1), .EXTERNAL_DIGITS(EXTERNAL_DIGITS)) footer (
        .credit_digits(credit_digits),
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

    wire [3:0] live_category = state == 5 ? result_category : hand_category;
    wire odd_name = live_category == 1 || live_category == 3 || live_category == 5 || live_category == 9;
    wire [3:0] name_px={x[3] ^ odd_name,x[2:0]};
    assign hand_pixel_x={1'b0,name_px};
    assign hand_pixel_y={1'b0,~y[3],y[2:0]};
    assign hand_yellow=state==4 || state==5;
    assign hand_text_active=(state==2 || state==4 || state==5) && y>=216 && y<228 && x>=192 && x<448 && name_px<12;
    wire [5:0] table_character;
    assign table_character[0] = (live_category == 4'd1 && (x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd19 || x[7:3]==5'd20)) || (live_category == 4'd2 && (x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13)) || (live_category == 4'd3 && (x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18)) || (live_category == 4'd4 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11)) || (live_category == 4'd5 && (x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10)) || (live_category == 4'd6 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17)) || (live_category == 4'd7 && (x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17)) || (live_category == 4'd8 && (x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19)) || (live_category == 4'd9 && (x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16));
    assign table_character[1] = (live_category == 4'd1 && (x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20)) || (live_category == 4'd2 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13)) || (live_category == 4'd3 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd4 && (x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd5 && (x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd11 || x[7:3]==5'd12)) || (live_category == 4'd6 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd16 || x[7:3]==5'd17)) || (live_category == 4'd7 && (x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd20 || x[7:3]==5'd21)) || (live_category == 4'd8 && (x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd20 || x[7:3]==5'd21)) || (live_category == 4'd9 && (x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd17 || x[7:3]==5'd18));
    assign table_character[2] = (live_category == 4'd1 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd2 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd3 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd4 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd5 && (x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10)) || (live_category == 4'd6 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17)) || (live_category == 4'd7 && (x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd20 || x[7:3]==5'd21)) || (live_category == 4'd8 && (x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19)) || (live_category == 4'd9 && (x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16));
    assign table_character[3] = (live_category == 4'd1 && (x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd2 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd3 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd19 || x[7:3]==5'd20 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd4 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd5 && (x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10)) || (live_category == 4'd6 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17)) || (live_category == 4'd7 && (x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20 || x[7:3]==5'd21)) || (live_category == 4'd8 && (x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19)) || (live_category == 4'd9 && (x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16));
    assign table_character[4] = (live_category == 4'd1 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd21 || x[7:3]==5'd22)) || (live_category == 4'd2 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd3 && (x[7:3]==5'd25 || x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20)) || (live_category == 4'd4 && (x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd5 && (x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12)) || (live_category == 4'd6 && (x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15)) || (live_category == 4'd7 && (x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd1 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19)) || (live_category == 4'd8 && (x[7:3]==5'd26 || x[7:3]==5'd27 || x[7:3]==5'd28 || x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd2 || x[7:3]==5'd3 || x[7:3]==5'd4 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd7 || x[7:3]==5'd8 || x[7:3]==5'd9 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18 || x[7:3]==5'd19 || x[7:3]==5'd20 || x[7:3]==5'd21)) || (live_category == 4'd9 && (x[7:3]==5'd29 || x[7:3]==5'd30 || x[7:3]==5'd31 || x[7:3]==5'd0 || x[7:3]==5'd5 || x[7:3]==5'd6 || x[7:3]==5'd9 || x[7:3]==5'd10 || x[7:3]==5'd11 || x[7:3]==5'd12 || x[7:3]==5'd13 || x[7:3]==5'd14 || x[7:3]==5'd15 || x[7:3]==5'd16 || x[7:3]==5'd17 || x[7:3]==5'd18));
    assign table_character[5] = (live_category == 4'd2 && (x[7:3]==5'd2 || x[7:3]==5'd3)) || (live_category == 4'd9 && (x[7:3]==5'd1 || x[7:3]==5'd2));
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
    wire [3:0] shared20_x=hand_pixel_x[3:0];
    wire [3:0] shared20_y=hand_pixel_y[3:0];

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
    // Stage the glyph request, its background, and both sync signals together.
    reg [5:0] c;
    reg [3:0] row_q, col_q;
    reg active_q, yellow_q, card_q, red_q, background_q, visible_q;
    reg h1,v1,h2,v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {c,row_q,col_q} <= 0;
            {active_q,yellow_q,card_q,red_q,background_q} <= 0;
            visible_q <= 1; h1<=1; v1<=1;
        end else begin
            c<=font_character; row_q<=font_row; col_q<=font_column;
            {active_q,yellow_q,card_q,red_q,background_q,visible_q}
              <= {font_active,font_yellow,font_card,card_red,card_active,visible};
            h1<=h_raw; v1<=v_raw;
        end
    end
    wire ink;
    font_ink text_font(.character(c),.row(row_q),.col(4'd11-col_q),.ink(ink));
    wire text_pixel=active_q && ink;
    reg [1:0] red_d,green_d,blue_d;
    always @* begin
        red_d   = 2'b00;
        green_d = 2'b00;
        blue_d  = 2'b00;

        if (visible_q) begin
            // Green background
            green_d = 2'b10;

            // Card geometry is owned by card_faces.v, even before a deal.
            if (background_q) begin
                red_d   = 2'b11;
                green_d = 2'b11;
                blue_d  = 2'b11;
            end

            // Text is drawn last so glyph pixels overwrite the table panels.
            if (text_pixel) begin
                red_d   = card_q ? (red_q ? 2'b11 : 2'b00) : 2'b11;
                green_d = card_q ? 2'b00 : 2'b11;
                blue_d  = card_q ? 2'b00 : (yellow_q ? 2'b00 : 2'b11);
            end
        end
    end

    assign hsync=h2;
    assign vsync=v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {red,green,blue}<=6'b001000; h2<=1; v2<=1;
        end else begin
            {red,green,blue}<={red_d,green_d,blue_d}; h2<=h1; v2<=v1;
        end
    end
endmodule
