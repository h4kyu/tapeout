`default_nettype none

// Shared hand names and fixed payout amounts. Both the payout sheet and live
// hand message select this one lookup before the one shared font ROM.
module payout_characters (
    input wire numbers,
    input wire [3:0] text_row,
    input wire [3:0] column,
    output wire [5:0] character
);
    // Winning rows, top to bottom (fixed five-credit wager):
    // ROYAL FLUSH 4000, STRAIGHT FLUSH 250, FOUR OF A KIND 125,
    // FULL HOUSE 45, FLUSH 30, STRAIGHT 20, THREE OF A KIND 15,
    // TWO PAIR 10, JACKS OR BETTER 5.
    // Address 9'h0RC selects label row R / column C; 9'h1RC selects payout.
    function [5:0] payout_character;
        input numbers;
        input [3:0] text_row;
        input [3:0] column;
        begin
            case ({numbers, text_row, column})
                9'h101, 9'h102, 9'h103, 9'h113,
                9'h143, 9'h153, 9'h173: payout_character = 6'd1; // 0
                9'h121, 9'h162, 9'h172: payout_character = 6'd2; // 1
                9'h111, 9'h122, 9'h152: payout_character = 6'd3; // 2
                9'h142: payout_character = 6'd4; // 3
                9'h100, 9'h132: payout_character = 6'd5; // 4
                9'h112, 9'h123, 9'h133, 9'h163,
                9'h183: payout_character = 6'd6; // 5
                9'h003, 9'h013, 9'h028, 9'h053,
                9'h069, 9'h075, 9'h081: payout_character = 6'd11; // A
                9'h089: payout_character = 6'd12; // B
                9'h082: payout_character = 6'd13; // C
                9'h02D, 9'h06E: payout_character = 6'd14; // D
                9'h039, 9'h063, 9'h064, 9'h08A,
                9'h08D: payout_character = 6'd15; // E
                9'h006, 9'h019, 9'h020, 9'h026,
                9'h030, 9'h040, 9'h067: payout_character = 6'd16; // F
                9'h015, 9'h055: payout_character = 6'd17; // G
                9'h00A, 9'h016, 9'h01D, 9'h035,
                9'h044, 9'h056, 9'h061: payout_character = 6'd18; // H
                9'h014, 9'h02B, 9'h054, 9'h06C,
                9'h076: payout_character = 6'd19; // I
                9'h080: payout_character = 6'd20; // J
                9'h02A, 9'h06B, 9'h083: payout_character = 6'd21; // K
                9'h004, 9'h007, 9'h01A, 9'h032,
                9'h033, 9'h041: payout_character = 6'd22; // L
                9'h02C, 9'h06D: payout_character = 6'd24; // N
                9'h001, 9'h021, 9'h025, 9'h036,
                9'h066, 9'h072, 9'h086: payout_character = 6'd25; // O
                9'h074: payout_character = 6'd26; // P
                9'h000, 9'h012, 9'h023, 9'h052,
                9'h062, 9'h077, 9'h087, 9'h08E: payout_character = 6'd28; // R
                9'h009, 9'h010, 9'h01C, 9'h038,
                9'h043, 9'h050, 9'h084: payout_character = 6'd29; // S
                9'h011, 9'h017, 9'h051, 9'h057,
                9'h060, 9'h070, 9'h08B, 9'h08C: payout_character = 6'd30; // T
                9'h008, 9'h01B, 9'h022, 9'h031,
                9'h037, 9'h042: payout_character = 6'd31; // U
                9'h071: payout_character = 6'd33; // W
                9'h002: payout_character = 6'd35; // Y
                default: payout_character = 6'd0; // Space / unsupported address
            endcase
        end
    endfunction

    assign character = payout_character(numbers, text_row, column);
endmodule
