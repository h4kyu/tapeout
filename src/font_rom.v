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

// Full-row interface for font inspection. The chip requests one pixel directly.
module font_rom(input wire [5:0] character, input wire [3:0] row,
                output wire [11:0] pixels);
    for (genvar bit_index=0; bit_index<12; bit_index=bit_index+1) begin : columns
        font_ink glyph(.character(character), .row(row), .col(4'(bit_index)),
                       .ink(pixels[bit_index]));
    end
endmodule

module font_ink(input wire [5:0] character, input wire [3:0] row, col, output wire ink);
wire mask0 = (row==4'd0) || (row==4'd9);
wire mask1 = (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8);
wire mask2 = (row==4'd1) || (row==4'd8);
wire mask3 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask4 = (row==4'd2);
wire mask5 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd9) || (col==4'd10);
wire mask6 = (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask7 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask8 = (character==6'd1);
wire mask9 = (row==4'd0) || (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask10 = (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7);
wire mask11 = (row==4'd1) || (row==4'd2);
wire mask12 = (row==4'd8) || (row==4'd9);
wire mask13 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask14 = (character==6'd2);
wire mask15 = (row==4'd0) || (row==4'd5);
wire mask16 = (row==4'd1) || (row==4'd8) || (row==4'd9);
wire mask17 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask18 = (row==4'd3);
wire mask19 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5);
wire mask20 = (row==4'd4);
wire mask21 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8);
wire mask22 = (row==4'd6);
wire mask23 = (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask24 = (row==4'd7);
wire mask25 = (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask26 = (character==6'd3);
wire mask27 = (row==4'd0) || (row==4'd1);
wire mask28 = (col==4'd3) || (col==4'd4) || (col==4'd5);
wire mask29 = (row==4'd5);
wire mask30 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8);
wire mask31 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4);
wire mask32 = (row==4'd8);
wire mask33 = (row==4'd9);
wire mask34 = (character==6'd4);
wire mask35 = (row==4'd0);
wire mask36 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7);
wire mask37 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask38 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask39 = (row==4'd5) || (row==4'd6);
wire mask40 = (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask41 = (character==6'd5);
wire mask42 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask43 = (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask44 = (row==4'd3) || (row==4'd4) || (row==4'd8);
wire mask45 = (character==6'd6);
wire mask46 = (row==4'd1) || (row==4'd9);
wire mask47 = (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask48 = (row==4'd4) || (row==4'd5);
wire mask49 = (row==4'd6) || (row==4'd7);
wire mask50 = (character==6'd7);
wire mask51 = (row==4'd6) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask52 = (col==4'd6) || (col==4'd7) || (col==4'd8);
wire mask53 = (character==6'd8);
wire mask54 = (row==4'd0) || (row==4'd4);
wire mask55 = (row==4'd1);
wire mask56 = (col==4'd3) || (col==4'd4) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask57 = (col==4'd3) || (col==4'd4) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask58 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd10) || (col==4'd11);
wire mask59 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd10) || (col==4'd11);
wire mask60 = (character==6'd9);
wire mask61 = (row==4'd0) || (row==4'd8);
wire mask62 = (row==4'd2) || (row==4'd3);
wire mask63 = (character==6'd10);
wire mask64 = (row==4'd3) || (row==4'd4) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask65 = (character==6'd11);
wire mask66 = (row==4'd0) || (row==4'd4) || (row==4'd8) || (row==4'd9);
wire mask67 = (row==4'd2) || (row==4'd3) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask68 = (character==6'd12);
wire mask69 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask70 = (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6);
wire mask71 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask72 = (character==6'd13);
wire mask73 = (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask74 = (character==6'd14);
wire mask75 = (row==4'd0) || (row==4'd1) || (row==4'd8) || (row==4'd9);
wire mask76 = (row==4'd2) || (row==4'd3) || (row==4'd6) || (row==4'd7);
wire mask77 = (character==6'd15);
wire mask78 = (row==4'd2) || (row==4'd3) || (row==4'd6) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask79 = (character==6'd16);
wire mask80 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask81 = (character==6'd17);
wire mask82 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd3) || (row==4'd6) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask83 = (character==6'd18);
wire mask84 = (row==4'd2) || (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask85 = (character==6'd19);
wire mask86 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6);
wire mask87 = (character==6'd20);
wire mask88 = (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask89 = (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask90 = (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask91 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask92 = (character==6'd21);
wire mask93 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask94 = (character==6'd22);
wire mask95 = (row==4'd0) || (row==4'd8) || (row==4'd9);
wire mask96 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask97 = (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask98 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd6) || (col==4'd7) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask99 = (character==6'd23);
wire mask100 = (row==4'd0) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask101 = (col==4'd1) || (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10) || (col==4'd11);
wire mask102 = (character==6'd24);
wire mask103 = (character==6'd25);
wire mask104 = (row==4'd0) || (row==4'd6);
wire mask105 = (row==4'd1) || (row==4'd5);
wire mask106 = (row==4'd2) || (row==4'd3) || (row==4'd4);
wire mask107 = (character==6'd26);
wire mask108 = (col==4'd1) || (col==4'd2) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask109 = (character==6'd27);
wire mask110 = (row==4'd4) || (row==4'd9);
wire mask111 = (character==6'd28);
wire mask112 = (row==4'd0) || (row==4'd4) || (row==4'd9);
wire mask113 = (row==4'd2) || (row==4'd7);
wire mask114 = (character==6'd29);
wire mask115 = (row==4'd2) || (row==4'd3) || (row==4'd4) || (row==4'd5) || (row==4'd6) || (row==4'd7) || (row==4'd8) || (row==4'd9);
wire mask116 = (character==6'd30);
wire mask117 = (character==6'd31);
wire mask118 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd3);
wire mask119 = (row==4'd7) || (row==4'd8);
wire mask120 = (col==4'd6) || (col==4'd7);
wire mask121 = (character==6'd32);
wire mask122 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd3) || (row==4'd4);
wire mask123 = (row==4'd5) || (row==4'd6) || (row==4'd7);
wire mask124 = (col==4'd3) || (col==4'd4) || (col==4'd9) || (col==4'd10);
wire mask125 = (character==6'd33);
wire mask126 = (row==4'd0) || (row==4'd1) || (row==4'd2) || (row==4'd8) || (row==4'd9);
wire mask127 = (row==4'd3) || (row==4'd6);
wire mask128 = (character==6'd34);
wire mask129 = (character==6'd35);
wire mask130 = (row==4'd3) || (row==4'd4);
wire mask131 = (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9) || (col==4'd10);
wire mask132 = (character==6'd36);
wire mask133 = (row==4'd0) || (row==4'd3) || (row==4'd10);
wire mask134 = (row==4'd1) || (row==4'd2) || (row==4'd11);
wire mask135 = (row==4'd4) || (row==4'd8);
wire mask136 = (col==4'd2) || (col==4'd3) || (col==4'd5) || (col==4'd6) || (col==4'd8) || (col==4'd9);
wire mask137 = (col==4'd5) || (col==4'd6);
wire mask138 = (character==6'd37);
wire mask139 = (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd5) || (col==4'd6) || (col==4'd7) || (col==4'd8) || (col==4'd9);
wire mask140 = (character==6'd38);
wire mask141 = (col==4'd2) || (col==4'd3) || (col==4'd4) || (col==4'd7) || (col==4'd8) || (col==4'd9);
wire mask142 = (character==6'd39);
wire mask143 = (row==4'd1) || (row==4'd10);
wire mask144 = (row==4'd2) || (row==4'd3) || (row==4'd11);
wire mask145 = (character==6'd40);
assign ink = (mask8 & ((mask0 & mask1) | (mask2 & mask3) | (mask4 & mask5) | (mask6 & mask7))) |
(mask14 & ((mask9 & mask10) | (mask11 & mask1) | (mask12 & mask13))) |
(mask26 & ((mask15 & mask3) | (mask16 & mask17) | (mask4 & mask7) | (mask18 & mask19) | (mask20 & mask21) | (mask22 & mask23) | (mask24 & mask25))) |
(mask34 & ((mask27 & mask13) | (mask4 & mask28) | (mask18 & mask10) | (mask20 & mask21) | (mask29 & mask30) | (mask22 & mask31) | (mask24 & mask7) | (mask32 & mask17) | (mask33 & mask3))) |
(mask41 & ((mask35 & mask36) | (mask11 & mask21) | (mask18 & mask37) | (mask20 & mask38) | (mask39 & mask17) | (mask40 & mask28))) |
(mask45 & ((mask27 & mask42) | (mask4 & mask43) | (mask44 & mask17) | (mask39 & mask31) | (mask24 & mask7) | (mask33 & mask3))) |
(mask50 & ((mask35 & mask21) | (mask46 & mask3) | (mask4 & mask47) | (mask18 & mask43) | (mask48 & mask42) | (mask49 & mask7) | (mask32 & mask17))) |
(mask53 & ((mask27 & mask17) | (mask4 & mask7) | (mask18 & mask28) | (mask20 & mask36) | (mask29 & mask1) | (mask51 & mask52))) |
(mask60 & ((mask54 & mask23) | (mask55 & mask42) | (mask4 & mask56) | (mask18 & mask57) | (mask29 & mask17) | (mask22 & mask58) | (mask24 & mask59) | (mask12 & mask3))) |
(mask63 & ((mask61 & mask3) | (mask55 & mask17) | (mask62 & mask7) | (mask48 & mask13) | (mask22 & mask31) | (mask24 & mask28) | (mask33 & mask23))) |
(mask65 & ((mask35 & mask1) | (mask55 & mask3) | (mask4 & mask37) | (mask64 & mask7) | (mask39 & mask17))) |
(mask68 & ((mask66 & mask42) | (mask55 & mask17) | (mask67 & mask7))) |
(mask72 & ((mask0 & mask21) | (mask2 & mask13) | (mask4 & mask69) | (mask70 & mask43) | (mask24 & mask71))) |
(mask74 & ((mask0 & mask73) | (mask2 & mask42) | (mask4 & mask38) | (mask6 & mask7))) |
(mask77 & ((mask75 & mask17) | (mask76 & mask43) | (mask48 & mask42))) |
(mask79 & ((mask27 & mask17) | (mask78 & mask43) | (mask48 & mask42))) |
(mask81 & ((mask0 & mask30) | (mask2 & mask13) | (mask4 & mask47) | (mask18 & mask43) | (mask48 & mask80) | (mask49 & mask7))) |
(mask83 & ((mask82 & mask7) | (mask48 & mask17))) |
(mask85 & ((mask75 & mask13) | (mask84 & mask10))) |
(mask87 & ((mask86 & mask31) | (mask24 & mask7) | (mask32 & mask17) | (mask33 & mask3))) |
(mask92 & ((mask35 & mask7) | (mask46 & mask80) | (mask4 & mask38) | (mask18 & mask88) | (mask20 & mask89) | (mask39 & mask73) | (mask24 & mask90) | (mask32 & mask91))) |
(mask94 & ((mask93 & mask47) | (mask12 & mask13))) |
(mask99 & ((mask95 & mask7) | (mask11 & mask96) | (mask18 & mask17) | (mask97 & mask98))) |
(mask102 & ((mask100 & mask7) | (mask11 & mask71) | (mask18 & mask101) | (mask48 & mask91) | (mask22 & mask80))) |
(mask103 & ((mask0 & mask3) | (mask2 & mask17) | (mask84 & mask7))) |
(mask107 & ((mask104 & mask42) | (mask105 & mask17) | (mask106 & mask7) | (mask40 & mask43))) |
(mask109 & ((mask35 & mask3) | (mask2 & mask17) | (mask106 & mask7) | (mask39 & mask91) | (mask24 & mask38) | (mask33 & mask108))) |
(mask111 & ((mask35 & mask42) | (mask105 & mask17) | (mask62 & mask7) | (mask110 & mask80) | (mask22 & mask73) | (mask24 & mask90) | (mask32 & mask91))) |
(mask114 & ((mask112 & mask3) | (mask2 & mask17) | (mask113 & mask7) | (mask18 & mask43) | (mask29 & mask13) | (mask22 & mask31))) |
(mask116 & ((mask27 & mask13) | (mask115 & mask10))) |
(mask117 & ((mask93 & mask7) | (mask32 & mask17) | (mask33 & mask3))) |
(mask121 & ((mask118 & mask7) | (mask20 & mask96) | (mask29 & mask17) | (mask22 & mask3) | (mask119 & mask1) | (mask33 & mask120))) |
(mask125 & ((mask122 & mask98) | (mask123 & mask17) | (mask12 & mask124))) |
(mask128 & ((mask126 & mask7) | (mask127 & mask37) | (mask48 & mask1) | (mask24 & mask96))) |
(mask129 & ((mask118 & mask69) | (mask20 & mask13) | (mask29 & mask21) | (mask51 & mask10))) |
(mask132 & ((mask75 & mask17) | (mask4 & mask19) | (mask130 & mask36) | (mask29 & mask1) | (mask49 & mask131))) |
(mask138 & ((mask133 & mask10) | (mask134 & mask21) | (mask135 & mask136) | (mask123 & mask13) | (mask33 & mask137))) |
(mask140 & ((mask0 & mask137) | (mask2 & mask10) | (mask113 & mask21) | (mask127 & mask139) | (mask48 & mask13))) |
(mask142 & ((mask27 & mask141) | (mask106 & mask13) | (mask39 & mask139) | (mask24 & mask21) | (mask32 & mask10) | (mask33 & mask137))) |
(mask145 & ((mask0 & mask137) | (mask143 & mask10) | (mask144 & mask21) | (mask20 & mask139) | (mask123 & mask13) | (mask32 & mask136)));
endmodule
