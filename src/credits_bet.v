`default_nettype none

// Footer glyph requests. Uses the shared font ROM in vga.v; no ROM here.
// BET, credits, and result share native 12-pixel cells with yellow text.
module credits_bet #(parameter MULTIPLE_OF_FIVE=0, parameter EXTERNAL_DIGITS=0) (
    input wire [19:0] credit_digits,
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
    reg [17:0] decimal_shift;
    reg [4:0] bits_left;
    wire busy=(bits_left != 5'd0);
    reg [19:0] adjusted_digits;
    integer digit;

    function [3:0] adjust_bcd;
        input [3:0] nibble;
        begin
            case(nibble)
                4'd0:adjust_bcd=4'd0;
                4'd1:adjust_bcd=4'd1;
                4'd2:adjust_bcd=4'd2;
                4'd3:adjust_bcd=4'd3;
                4'd4:adjust_bcd=4'd4;
                4'd5:adjust_bcd=4'd8;
                4'd6:adjust_bcd=4'd9;
                4'd7:adjust_bcd=4'd10;
                4'd8:adjust_bcd=4'd11;
                4'd9:adjust_bcd=4'd12;
                default:adjust_bcd=4'bx;
            endcase
        end
    endfunction
    always @* begin
        adjusted_digits={2'b00,decimal_shift};
        for(digit=0;digit<4;digit=digit+1)
            adjusted_digits[digit*4 +:4]=adjust_bcd(decimal_shift[digit*4 +:4]);
    end

    wire [19:0] next_digits = {adjusted_digits[18:0], sampled_balance[bits_left[3:0]-4'd1]};

    wire work_clock, sample_clock, display_clock;
    wire changed=(balance!=sampled_balance);
    clock_gate work_gate(.clk(clk),.enable(busy || changed),.gated_clk(work_clock));
    clock_gate sample_gate(.clk(clk),.enable(!busy && changed),.gated_clk(sample_clock));
    clock_gate display_gate(.clk(clk),.enable(busy && bits_left==1),.gated_clk(display_clock));
    always @(posedge sample_clock or negedge rst_n) begin
        if(!rst_n) sampled_balance<=16'd100;
        else sampled_balance<=balance;
    end
    always @(posedge display_clock or negedge rst_n) begin
        if(!rst_n) displayed_digits<=20'h00100;
        // Production balances are multiples of five: reset=100, wager=5,
        // every award is a multiple of five, and saturation=65535. Thus the
        // units digit needs one stored bit (0 or 5), not four independent FFs.
        else if(MULTIPLE_OF_FIVE)
            displayed_digits<={next_digits[19:4],1'b0,next_digits[0],1'b0,next_digits[0]};
        else displayed_digits<=next_digits;
    end
    always @(posedge work_clock or negedge rst_n) begin
        if(!rst_n) begin decimal_shift<=0; bits_left<=0; end
        else begin
            decimal_shift<=busy ? next_digits[17:0] : 18'd0;
            bits_left<=busy ? bits_left-5'd1 : 5'd16;
        end
    end

    wire [19:0] digits = EXTERNAL_DIGITS ? credit_digits : displayed_digits;
    reg [3:0] credit_digit;
    wire [3:0] digit_id=credit_digit+4'd1;
    always @* begin
        case (column)
            0: credit_digit=digits[19:16];
            1: credit_digit=digits[15:12];
            2: credit_digit=digits[11:8];
            3: credit_digit=digits[7:4];
            4: credit_digit=digits[3:0];
            default: credit_digit=0;
        endcase
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

    // Fixed five-digit balance and nine-cell result field keep positions constant.
    wire [5:0] cell_id=x[9:4];
    wire [3:0] column=x[7:4] - (cell_id<26 ? 0 : cell_id<34 ? 10 : 2);
    wire [2:0] region = cell_id>=26 && cell_id<=32 ? 2 : cell_id>=34 && cell_id<=38 ? 3 :
            cell_id>=16 && cell_id<=24 && result_ready ? 4 : 0;
    wire [4:0] x_offset={1'b0,x[3:0]};
    wire [4:0] y_offset={1'b0,y[3:0]};
    always @* begin
        character=0;
        text_active=region!=0 && y>=448 && y<460 && x[3:0]<12;
        if (text_active) begin
            case (region)
                2'd2: character = credits_character(column[2:0]);
                2'd3: character = {2'b00, digit_id};
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
