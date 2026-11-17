/*
 * Glyph data: Copyright 2012 The Press Start 2P Project Authors (cody@zone38.net).
 * SPDX-License-Identifier: OFL-1.1
 * See docs/press-start-2p-OFL.txt for the font license.
 * Source: https://github.com/google/fonts/tree/main/ofl/pressstart2p
 * TTF SHA256: 034c77f1f05ec89421e4a63f0e3a4ca1ecf852cc6d2bf611f126f275728e017d
 * Suit masks (IDs 37..40) are original 12px glyphs.
 * Letters/digits rasterized at 12 px with Pillow/FreeType in monochrome mode, origin (0, 0).
 */
`default_nettype none

// Character IDs: 0=space, 1..10='0'..'9', 11..36='A'..'Z',
// 37=club, 38=diamond, 39=heart, 40=spade.
// Combinational font ROM: row 0 is the top; pixels[11] is the leftmost pixel.
// Unsupported character IDs and rows 12..15 produce a blank row.
module font_rom (
    input  wire [5:0] character,
    input  wire [3:0] row,
    output wire [11:0] pixels
);
    // Addresses sharing a row pattern are grouped into one case arm.
    function [11:0] font_row;
        input [5:0] character_id;
        input [3:0] row_index;
        begin
            case ({character_id, row_index})
                {6'd1, 4'd0}, // 0, row 0
                {6'd1, 4'd9}, // 0, row 9
                {6'd2, 4'd1}, // 1, row 1
                {6'd2, 4'd2}, // 1, row 2
                {6'd8, 4'd5}, // 7, row 5
                {6'd11, 4'd0}, // A, row 0
                {6'd32, 4'd7}, // V, row 7
                {6'd32, 4'd8}, // V, row 8
                {6'd34, 4'd4}, // X, row 4
                {6'd34, 4'd5}, // X, row 5
                {6'd36, 4'd5}: // Z, row 5
                    font_row = 12'b000111110000;

                {6'd1, 4'd1}, // 0, row 1
                {6'd1, 4'd8}, // 0, row 8
                {6'd3, 4'd0}, // 2, row 0
                {6'd3, 4'd5}, // 2, row 5
                {6'd4, 4'd9}, // 3, row 9
                {6'd6, 4'd9}, // 5, row 9
                {6'd7, 4'd1}, // 6, row 1
                {6'd7, 4'd9}, // 6, row 9
                {6'd9, 4'd8}, // 8, row 8
                {6'd9, 4'd9}, // 8, row 9
                {6'd10, 4'd0}, // 9, row 0
                {6'd10, 4'd8}, // 9, row 8
                {6'd11, 4'd1}, // A, row 1
                {6'd20, 4'd9}, // J, row 9
                {6'd25, 4'd0}, // O, row 0
                {6'd25, 4'd9}, // O, row 9
                {6'd27, 4'd0}, // Q, row 0
                {6'd29, 4'd0}, // S, row 0
                {6'd29, 4'd4}, // S, row 4
                {6'd29, 4'd9}, // S, row 9
                {6'd31, 4'd9}, // U, row 9
                {6'd32, 4'd6}: // V, row 6
                    font_row = 12'b011111111000;

                {6'd1, 4'd2}: // 0, row 2
                    font_row = 12'b011000111000;

                {6'd1, 4'd3}, // 0, row 3
                {6'd1, 4'd4}, // 0, row 4
                {6'd1, 4'd5}, // 0, row 5
                {6'd1, 4'd6}, // 0, row 6
                {6'd1, 4'd7}, // 0, row 7
                {6'd3, 4'd2}, // 2, row 2
                {6'd4, 4'd7}, // 3, row 7
                {6'd6, 4'd7}, // 5, row 7
                {6'd7, 4'd6}, // 6, row 6
                {6'd7, 4'd7}, // 6, row 7
                {6'd8, 4'd2}, // 7, row 2
                {6'd10, 4'd2}, // 9, row 2
                {6'd10, 4'd3}, // 9, row 3
                {6'd11, 4'd3}, // A, row 3
                {6'd11, 4'd4}, // A, row 4
                {6'd11, 4'd7}, // A, row 7
                {6'd11, 4'd8}, // A, row 8
                {6'd11, 4'd9}, // A, row 9
                {6'd12, 4'd2}, // B, row 2
                {6'd12, 4'd3}, // B, row 3
                {6'd12, 4'd5}, // B, row 5
                {6'd12, 4'd6}, // B, row 6
                {6'd12, 4'd7}, // B, row 7
                {6'd14, 4'd3}, // D, row 3
                {6'd14, 4'd4}, // D, row 4
                {6'd14, 4'd5}, // D, row 5
                {6'd14, 4'd6}, // D, row 6
                {6'd14, 4'd7}, // D, row 7
                {6'd17, 4'd6}, // G, row 6
                {6'd17, 4'd7}, // G, row 7
                {6'd18, 4'd0}, // H, row 0
                {6'd18, 4'd1}, // H, row 1
                {6'd18, 4'd2}, // H, row 2
                {6'd18, 4'd3}, // H, row 3
                {6'd18, 4'd6}, // H, row 6
                {6'd18, 4'd7}, // H, row 7
                {6'd18, 4'd8}, // H, row 8
                {6'd18, 4'd9}, // H, row 9
                {6'd20, 4'd7}, // J, row 7
                {6'd21, 4'd0}, // K, row 0
                {6'd23, 4'd0}, // M, row 0
                {6'd23, 4'd8}, // M, row 8
                {6'd23, 4'd9}, // M, row 9
                {6'd24, 4'd0}, // N, row 0
                {6'd24, 4'd7}, // N, row 7
                {6'd24, 4'd8}, // N, row 8
                {6'd24, 4'd9}, // N, row 9
                {6'd25, 4'd2}, // O, row 2
                {6'd25, 4'd3}, // O, row 3
                {6'd25, 4'd4}, // O, row 4
                {6'd25, 4'd5}, // O, row 5
                {6'd25, 4'd6}, // O, row 6
                {6'd25, 4'd7}, // O, row 7
                {6'd26, 4'd2}, // P, row 2
                {6'd26, 4'd3}, // P, row 3
                {6'd26, 4'd4}, // P, row 4
                {6'd27, 4'd2}, // Q, row 2
                {6'd27, 4'd3}, // Q, row 3
                {6'd27, 4'd4}, // Q, row 4
                {6'd28, 4'd2}, // R, row 2
                {6'd28, 4'd3}, // R, row 3
                {6'd29, 4'd2}, // S, row 2
                {6'd29, 4'd7}, // S, row 7
                {6'd31, 4'd0}, // U, row 0
                {6'd31, 4'd1}, // U, row 1
                {6'd31, 4'd2}, // U, row 2
                {6'd31, 4'd3}, // U, row 3
                {6'd31, 4'd4}, // U, row 4
                {6'd31, 4'd5}, // U, row 5
                {6'd31, 4'd6}, // U, row 6
                {6'd31, 4'd7}, // U, row 7
                {6'd32, 4'd0}, // V, row 0
                {6'd32, 4'd1}, // V, row 1
                {6'd32, 4'd2}, // V, row 2
                {6'd32, 4'd3}, // V, row 3
                {6'd34, 4'd0}, // X, row 0
                {6'd34, 4'd1}, // X, row 1
                {6'd34, 4'd2}, // X, row 2
                {6'd34, 4'd8}, // X, row 8
                {6'd34, 4'd9}: // X, row 9
                    font_row = 12'b111000011110;

                {6'd2, 4'd0}, // 1, row 0
                {6'd2, 4'd3}, // 1, row 3
                {6'd2, 4'd4}, // 1, row 4
                {6'd2, 4'd5}, // 1, row 5
                {6'd2, 4'd6}, // 1, row 6
                {6'd2, 4'd7}, // 1, row 7
                {6'd4, 4'd3}, // 3, row 3
                {6'd19, 4'd2}, // I, row 2
                {6'd19, 4'd3}, // I, row 3
                {6'd19, 4'd4}, // I, row 4
                {6'd19, 4'd5}, // I, row 5
                {6'd19, 4'd6}, // I, row 6
                {6'd19, 4'd7}, // I, row 7
                {6'd30, 4'd2}, // T, row 2
                {6'd30, 4'd3}, // T, row 3
                {6'd30, 4'd4}, // T, row 4
                {6'd30, 4'd5}, // T, row 5
                {6'd30, 4'd6}, // T, row 6
                {6'd30, 4'd7}, // T, row 7
                {6'd30, 4'd8}, // T, row 8
                {6'd30, 4'd9}, // T, row 9
                {6'd35, 4'd6}, // Y, row 6
                {6'd35, 4'd7}, // Y, row 7
                {6'd35, 4'd8}, // Y, row 8
                {6'd35, 4'd9}, // Y, row 9
                {6'd37, 4'd0}, // club, row 0
                {6'd37, 4'd3}, // club, row 3
                {6'd37, 4'd10}, // club, row 10
                {6'd38, 4'd1}, // diamond, row 1
                {6'd38, 4'd8}, // diamond, row 8
                {6'd39, 4'd8}, // heart, row 8
                {6'd40, 4'd1}, // spade, row 1
                {6'd40, 4'd10}: // spade, row 10
                    font_row = 12'b000011110000;

                {6'd2, 4'd8}, // 1, row 8
                {6'd2, 4'd9}, // 1, row 9
                {6'd4, 4'd0}, // 3, row 0
                {6'd4, 4'd1}, // 3, row 1
                {6'd10, 4'd4}, // 9, row 4
                {6'd10, 4'd5}, // 9, row 5
                {6'd13, 4'd1}, // C, row 1
                {6'd13, 4'd8}, // C, row 8
                {6'd17, 4'd1}, // G, row 1
                {6'd17, 4'd8}, // G, row 8
                {6'd19, 4'd0}, // I, row 0
                {6'd19, 4'd1}, // I, row 1
                {6'd19, 4'd8}, // I, row 8
                {6'd19, 4'd9}, // I, row 9
                {6'd22, 4'd8}, // L, row 8
                {6'd22, 4'd9}, // L, row 9
                {6'd29, 4'd5}, // S, row 5
                {6'd30, 4'd0}, // T, row 0
                {6'd30, 4'd1}, // T, row 1
                {6'd35, 4'd4}, // Y, row 4
                {6'd37, 4'd5}, // club, row 5
                {6'd37, 4'd6}, // club, row 6
                {6'd37, 4'd7}, // club, row 7
                {6'd38, 4'd4}, // diamond, row 4
                {6'd38, 4'd5}, // diamond, row 5
                {6'd39, 4'd2}, // heart, row 2
                {6'd39, 4'd3}, // heart, row 3
                {6'd39, 4'd4}, // heart, row 4
                {6'd40, 4'd5}, // spade, row 5
                {6'd40, 4'd6}, // spade, row 6
                {6'd40, 4'd7}: // spade, row 7
                    font_row = 12'b011111111110;

                {6'd3, 4'd1}, // 2, row 1
                {6'd3, 4'd8}, // 2, row 8
                {6'd3, 4'd9}, // 2, row 9
                {6'd4, 4'd8}, // 3, row 8
                {6'd5, 4'd5}, // 4, row 5
                {6'd5, 4'd6}, // 4, row 6
                {6'd6, 4'd3}, // 5, row 3
                {6'd6, 4'd4}, // 5, row 4
                {6'd6, 4'd8}, // 5, row 8
                {6'd7, 4'd8}, // 6, row 8
                {6'd8, 4'd0}, // 7, row 0
                {6'd8, 4'd1}, // 7, row 1
                {6'd9, 4'd5}, // 8, row 5
                {6'd10, 4'd1}, // 9, row 1
                {6'd11, 4'd5}, // A, row 5
                {6'd11, 4'd6}, // A, row 6
                {6'd12, 4'd1}, // B, row 1
                {6'd15, 4'd0}, // E, row 0
                {6'd15, 4'd1}, // E, row 1
                {6'd15, 4'd8}, // E, row 8
                {6'd15, 4'd9}, // E, row 9
                {6'd16, 4'd0}, // F, row 0
                {6'd16, 4'd1}, // F, row 1
                {6'd18, 4'd4}, // H, row 4
                {6'd18, 4'd5}, // H, row 5
                {6'd20, 4'd8}, // J, row 8
                {6'd23, 4'd3}, // M, row 3
                {6'd25, 4'd1}, // O, row 1
                {6'd25, 4'd8}, // O, row 8
                {6'd26, 4'd1}, // P, row 1
                {6'd26, 4'd5}, // P, row 5
                {6'd27, 4'd1}, // Q, row 1
                {6'd27, 4'd8}, // Q, row 8
                {6'd28, 4'd1}, // R, row 1
                {6'd28, 4'd5}, // R, row 5
                {6'd29, 4'd1}, // S, row 1
                {6'd29, 4'd8}, // S, row 8
                {6'd31, 4'd8}, // U, row 8
                {6'd32, 4'd5}, // V, row 5
                {6'd33, 4'd5}, // W, row 5
                {6'd33, 4'd6}, // W, row 6
                {6'd33, 4'd7}, // W, row 7
                {6'd36, 4'd0}, // Z, row 0
                {6'd36, 4'd1}, // Z, row 1
                {6'd36, 4'd8}, // Z, row 8
                {6'd36, 4'd9}: // Z, row 9
                    font_row = 12'b111111111110;

                {6'd3, 4'd3}, // 2, row 3
                {6'd36, 4'd2}: // Z, row 2
                    font_row = 12'b000000111110;

                {6'd3, 4'd4}, // 2, row 4
                {6'd4, 4'd4}, // 3, row 4
                {6'd5, 4'd1}, // 4, row 1
                {6'd5, 4'd2}, // 4, row 2
                {6'd7, 4'd0}, // 6, row 0
                {6'd13, 4'd0}, // C, row 0
                {6'd13, 4'd9}, // C, row 9
                {6'd35, 4'd5}, // Y, row 5
                {6'd37, 4'd1}, // club, row 1
                {6'd37, 4'd2}, // club, row 2
                {6'd37, 4'd11}, // club, row 11
                {6'd38, 4'd2}, // diamond, row 2
                {6'd38, 4'd7}, // diamond, row 7
                {6'd39, 4'd7}, // heart, row 7
                {6'd40, 4'd2}, // spade, row 2
                {6'd40, 4'd3}, // spade, row 3
                {6'd40, 4'd11}: // spade, row 11
                    font_row = 12'b000111111000;

                {6'd3, 4'd6}, // 2, row 6
                {6'd9, 4'd0}, // 8, row 0
                {6'd9, 4'd4}, // 8, row 4
                {6'd10, 4'd9}: // 9, row 9
                    font_row = 12'b011111110000;

                {6'd3, 4'd7}: // 2, row 7
                    font_row = 12'b111110000000;

                {6'd4, 4'd2}, // 3, row 2
                {6'd5, 4'd7}, // 4, row 7
                {6'd5, 4'd8}, // 4, row 8
                {6'd5, 4'd9}, // 4, row 9
                {6'd8, 4'd3}, // 7, row 3
                {6'd10, 4'd7}: // 9, row 7
                    font_row = 12'b000000111000;

                {6'd4, 4'd5}, // 3, row 5
                {6'd17, 4'd0}, // G, row 0
                {6'd17, 4'd9}: // G, row 9
                    font_row = 12'b000111111110;

                {6'd4, 4'd6}, // 3, row 6
                {6'd6, 4'd5}, // 5, row 5
                {6'd6, 4'd6}, // 5, row 6
                {6'd10, 4'd6}, // 9, row 6
                {6'd20, 4'd0}, // J, row 0
                {6'd20, 4'd1}, // J, row 1
                {6'd20, 4'd2}, // J, row 2
                {6'd20, 4'd3}, // J, row 3
                {6'd20, 4'd4}, // J, row 4
                {6'd20, 4'd5}, // J, row 5
                {6'd20, 4'd6}, // J, row 6
                {6'd29, 4'd6}: // S, row 6
                    font_row = 12'b000000011110;

                {6'd5, 4'd0}, // 4, row 0
                {6'd8, 4'd4}, // 7, row 4
                {6'd36, 4'd3}, // Z, row 3
                {6'd36, 4'd4}: // Z, row 4
                    font_row = 12'b000011111000;

                {6'd5, 4'd3}, // 4, row 3
                {6'd11, 4'd2}, // A, row 2
                {6'd34, 4'd3}, // X, row 3
                {6'd34, 4'd6}: // X, row 6
                    font_row = 12'b011110111000;

                {6'd5, 4'd4}, // 4, row 4
                {6'd14, 4'd2}, // D, row 2
                {6'd21, 4'd2}, // K, row 2
                {6'd27, 4'd7}: // Q, row 7
                    font_row = 12'b111000111000;

                {6'd6, 4'd0}, // 5, row 0
                {6'd6, 4'd1}, // 5, row 1
                {6'd7, 4'd4}, // 6, row 4
                {6'd7, 4'd5}, // 6, row 5
                {6'd9, 4'd1}, // 8, row 1
                {6'd12, 4'd0}, // B, row 0
                {6'd12, 4'd4}, // B, row 4
                {6'd12, 4'd8}, // B, row 8
                {6'd12, 4'd9}, // B, row 9
                {6'd14, 4'd1}, // D, row 1
                {6'd14, 4'd8}, // D, row 8
                {6'd15, 4'd4}, // E, row 4
                {6'd15, 4'd5}, // E, row 5
                {6'd16, 4'd4}, // F, row 4
                {6'd16, 4'd5}, // F, row 5
                {6'd26, 4'd0}, // P, row 0
                {6'd26, 4'd6}, // P, row 6
                {6'd28, 4'd0}: // R, row 0
                    font_row = 12'b111111111000;

                {6'd6, 4'd2}, // 5, row 2
                {6'd7, 4'd3}, // 6, row 3
                {6'd13, 4'd3}, // C, row 3
                {6'd13, 4'd4}, // C, row 4
                {6'd13, 4'd5}, // C, row 5
                {6'd13, 4'd6}, // C, row 6
                {6'd15, 4'd2}, // E, row 2
                {6'd15, 4'd3}, // E, row 3
                {6'd15, 4'd6}, // E, row 6
                {6'd15, 4'd7}, // E, row 7
                {6'd16, 4'd2}, // F, row 2
                {6'd16, 4'd3}, // F, row 3
                {6'd16, 4'd6}, // F, row 6
                {6'd16, 4'd7}, // F, row 7
                {6'd16, 4'd8}, // F, row 8
                {6'd16, 4'd9}, // F, row 9
                {6'd17, 4'd3}, // G, row 3
                {6'd26, 4'd7}, // P, row 7
                {6'd26, 4'd8}, // P, row 8
                {6'd26, 4'd9}, // P, row 9
                {6'd29, 4'd3}: // S, row 3
                    font_row = 12'b111000000000;

                {6'd7, 4'd2}, // 6, row 2
                {6'd17, 4'd2}, // G, row 2
                {6'd22, 4'd0}, // L, row 0
                {6'd22, 4'd1}, // L, row 1
                {6'd22, 4'd2}, // L, row 2
                {6'd22, 4'd3}, // L, row 3
                {6'd22, 4'd4}, // L, row 4
                {6'd22, 4'd5}, // L, row 5
                {6'd22, 4'd6}, // L, row 6
                {6'd22, 4'd7}: // L, row 7
                    font_row = 12'b011110000000;

                {6'd8, 4'd6}, // 7, row 6
                {6'd8, 4'd7}, // 7, row 7
                {6'd8, 4'd8}, // 7, row 8
                {6'd8, 4'd9}: // 7, row 9
                    font_row = 12'b000111000000;

                {6'd9, 4'd2}: // 8, row 2
                    font_row = 12'b111000011000;

                {6'd9, 4'd3}: // 8, row 3
                    font_row = 12'b111110011000;

                {6'd9, 4'd6}: // 8, row 6
                    font_row = 12'b110011111110;

                {6'd9, 4'd7}: // 8, row 7
                    font_row = 12'b110000011110;

                {6'd13, 4'd2}, // C, row 2
                {6'd35, 4'd0}, // Y, row 0
                {6'd35, 4'd1}, // Y, row 1
                {6'd35, 4'd2}, // Y, row 2
                {6'd35, 4'd3}: // Y, row 3
                    font_row = 12'b011110011110;

                {6'd13, 4'd7}, // C, row 7
                {6'd24, 4'd1}, // N, row 1
                {6'd24, 4'd2}: // N, row 2
                    font_row = 12'b111110011110;

                {6'd14, 4'd0}, // D, row 0
                {6'd14, 4'd9}, // D, row 9
                {6'd21, 4'd5}, // K, row 5
                {6'd21, 4'd6}, // K, row 6
                {6'd28, 4'd6}: // R, row 6
                    font_row = 12'b111111110000;

                {6'd17, 4'd4}, // G, row 4
                {6'd17, 4'd5}, // G, row 5
                {6'd21, 4'd1}, // K, row 1
                {6'd21, 4'd9}, // K, row 9
                {6'd24, 4'd6}, // N, row 6
                {6'd28, 4'd4}, // R, row 4
                {6'd28, 4'd9}: // R, row 9
                    font_row = 12'b111000111110;

                {6'd21, 4'd3}: // K, row 3
                    font_row = 12'b111011110000;

                {6'd21, 4'd4}: // K, row 4
                    font_row = 12'b111111000000;

                {6'd21, 4'd7}, // K, row 7
                {6'd28, 4'd7}: // R, row 7
                    font_row = 12'b111011111000;

                {6'd21, 4'd8}, // K, row 8
                {6'd24, 4'd4}, // N, row 4
                {6'd24, 4'd5}, // N, row 5
                {6'd27, 4'd5}, // Q, row 5
                {6'd27, 4'd6}, // Q, row 6
                {6'd28, 4'd8}: // R, row 8
                    font_row = 12'b111011111110;

                {6'd23, 4'd1}, // M, row 1
                {6'd23, 4'd2}, // M, row 2
                {6'd32, 4'd4}, // V, row 4
                {6'd34, 4'd7}: // X, row 7
                    font_row = 12'b111110111110;

                {6'd23, 4'd4}, // M, row 4
                {6'd23, 4'd5}, // M, row 5
                {6'd23, 4'd6}, // M, row 6
                {6'd23, 4'd7}, // M, row 7
                {6'd33, 4'd0}, // W, row 0
                {6'd33, 4'd1}, // W, row 1
                {6'd33, 4'd2}, // W, row 2
                {6'd33, 4'd3}, // W, row 3
                {6'd33, 4'd4}: // W, row 4
                    font_row = 12'b111011011110;

                {6'd24, 4'd3}: // N, row 3
                    font_row = 12'b111111011110;

                {6'd27, 4'd9}: // Q, row 9
                    font_row = 12'b011111110110;

                {6'd32, 4'd9}: // V, row 9
                    font_row = 12'b000011000000;

                {6'd33, 4'd8}, // W, row 8
                {6'd33, 4'd9}: // W, row 9
                    font_row = 12'b011000011000;

                {6'd36, 4'd6}, // Z, row 6
                {6'd36, 4'd7}: // Z, row 7
                    font_row = 12'b011111000000;

                {6'd37, 4'd4}, // club, row 4
                {6'd37, 4'd8}, // club, row 8
                {6'd40, 4'd8}: // spade, row 8
                    font_row = 12'b001101101100;

                {6'd37, 4'd9}, // club, row 9
                {6'd38, 4'd0}, // diamond, row 0
                {6'd38, 4'd9}, // diamond, row 9
                {6'd39, 4'd9}, // heart, row 9
                {6'd40, 4'd0}, // spade, row 0
                {6'd40, 4'd9}: // spade, row 9
                    font_row = 12'b000001100000;

                {6'd38, 4'd3}, // diamond, row 3
                {6'd38, 4'd6}, // diamond, row 6
                {6'd39, 4'd5}, // heart, row 5
                {6'd39, 4'd6}, // heart, row 6
                {6'd40, 4'd4}: // spade, row 4
                    font_row = 12'b001111111100;

                {6'd39, 4'd0}, // heart, row 0
                {6'd39, 4'd1}: // heart, row 1
                    font_row = 12'b001110011100;

                default: font_row = 12'b0;
            endcase
        end
    endfunction

    assign pixels = font_row(character, row);
endmodule
