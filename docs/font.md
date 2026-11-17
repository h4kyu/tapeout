# VGA font lookup

`src/font_rom.v` is a combinational 12×12 monochrome font lookup. It stores
Press Start 2P glyphs rasterized at 12 pixels, plus four original suit masks. Font data is built into the
Verilog; synthesis does not need a font file, Python, or external memory.

| Character ID (6 bits) | Glyph |
| --- | --- |
| 0 | Space |
| 1–10 | Digits 0–9 |
| 11–36 | Uppercase A–Z |
| 37–40 | Club, diamond, heart, spade |
| 41–63 | Blank |

For labels, store these IDs directly; there is no ASCII conversion in hardware.
For example, `ROYAL FLUSH` is `28,25,35,11,22,0,16,22,31,29,18`.

The renderer instantiates the lookup once:

```verilog
wire [11:0] glyph_pixels;

font_rom text_font (
    .character(character_id), // 6 bits: 11 selects A
    .row(glyph_y),            // 4 bits: 0..11, top to bottom
    .pixels(glyph_pixels)
);
```

`glyph_pixels[11]` is the leftmost pixel and `[0]` the rightmost. For a glyph
column `glyph_x` in 0..11, use `glyph_pixels[11 - glyph_x]` to decide whether to
paint the text color. Leave the underlying background color when the bit is 0.
Rows 12–15 and unsupported IDs return zero. The lookup has no clock or latency.
The experimental implementation factors identical vertical column masks across
glyphs, combines them with character decodes, and returns the same 12-bit row.
SAT checks the complete lookup against the original row-case implementation;
the chip test also preserves its full truth-table digest. The optional
`sim.synthesis.font_columns` tool regenerates this representation from the
baseline source.
Screen coordinates, label selection, text color, and any integer scaling belong
to the renderer. `vga.v` shares one lookup across all text, card ranks, and suit pips.

Glyph source: [Google Fonts' Press Start 2P](https://github.com/google/fonts/tree/main/ofl/pressstart2p).
The source TTF's SHA-256 and rasterization settings are recorded in `font_rom.v`.
The glyph data is licensed under the [SIL Open Font License](press-start-2p-OFL.txt).

`test/test_font.py` checks every character/row address, the blank fallbacks,
distinct glyphs, and the fixed pixel patterns for 0, A, and Z. It runs with `make`
against the standalone font instance in `test/tb.v`, including gate-level runs.

## Payout sheet

The nine winning categories run from royal flush down to jacks or better.
Fixed awards match the core's five-credit wager: 4000, 250, 125, 45, 30, 20,
15, 10, and 5. The `payout_character` function in the shared `payout_characters.v` lookup
addresses compact character IDs directly;
no ASCII or decimal conversion is used for this static table.

Labels start at x=35; four-character payout fields start at x=555 and end at
x=603. Both use 12×12 cells, with rows at y=29+18×row_index. Six-pixel row gaps
and blank glyph bits preserve the panel background. `payout_table.v` owns the
rectangles and positioning. It outputs panel colors plus a text-address request
(`text_active`, `numbers`, `text_row`, `text_column`, `glyph_x`, `glyph_y`); it
contains no font ROM. Text columns share a local-x decoder across labels and
awards; rows share a local-y decoder with explicit six-pixel gaps. Panel colors
use factored Boolean equations. `payout_characters.v` maps these addresses to character IDs
and shares its hand names with the live hand message. `vga.v` composites the panels and owns the single `text_font` instance.
Both columns share that lookup, and glyph pixels draw white after the panels.
Future text layers should select their character/row/column request in `vga.v`
before this same font instance, rather than instantiate additional font ROMs. Highlighting
based on the game result is separate future renderer work.

## HOLD labels

`hold_labels.v` requests the four glyphs H/O/L/D for each asserted bit of
`held_cards`. Labels start at x=51+121×card_index, y=246, using 12×12 glyphs
with two pixels between characters. The resulting 54-pixel word is centered
above each 110-pixel card. Blank glyph pixels and spacing preserve the green
background. Card/word selection now shares one local-coordinate and character
decoder for all five labels. `vga.v` draws the glyph pixels white through the same `text_font`
instance used by the payout sheet.

The labels use the core's `held_cards`, with no game-state visibility gate:
they follow selection in HOLD, stay frozen through DRAWING/RESULT, and clear
when a new round clears the held flags. Raw hold switches cannot erase the
previous round's labels during RESULT.

## CREDITS and BET 5

`credits_bet.v` requests BET, CREDITS, and result text through the shared font.
All footer fields use native 12×12 cells, with no resizing. BET 5 starts at
(25,446). CREDITS starts at (459,446), followed by a fixed five-digit,
zero-padded balance at (555,446), ending at x=615. The initial balance is `00100`;
the full 16-bit range up to 65535 is retained.

The result uses nine cells at (266,446), centered in the footer. All fields
share the same local-position and character-cell decoder. `vga.v` uses raw
footer offsets directly as font coordinates; its 20px scaling lookup now
serves only the hand-name message.

A five-digit serial double-dabble converter samples a changed balance, processes
16 binary bits, then commits the complete BCD value atomically. Input bits are
selected by index from the saved balance, avoiding a second 16-bit shifting
copy. Busy is derived from the remaining-bit count. One saved
input balance both identifies the conversion in progress and detects later
changes; no second balance copy is stored. It uses no `/`
or `%` operators. Stable changes appear after 17 clocks; a change during an
existing conversion settles within 34 clocks (1.36 microseconds at 25 MHz).
Reset immediately displays the core's initial balance of 00100. This conversion
does not stall gameplay or animate the digits.

## Live and final hand messages

`hand_message.v` centers a 20px hand name at y=213, above the HOLD labels. The
left edge is `(640 - 20*character_count)/2`, with names matching the payout sheet.
The core's existing evaluator supplies `hand_category`; no second evaluator is
instantiated. During HOLD, a qualifying live hand displays in white. Complete
hand classification in EVALUATE and the latched result in RESULT display yellow.
Category zero (including low pairs), reset/IDLE, and partial DEALING/DRAWING hands
are blank. Losing results do not display an extra message.

The message selects a row and column in the same `payout_characters` instance
used by the payout sheet, then uses the same `text_font` instance as all other
text. It adds neither a second name table nor a second font ROM. Footer text
stays yellow; payout/HOLD text stays white. Result highlighting in the payout
sheet itself remains separate future work.

Positioning uses a category lookup for the six possible centered origins,
then one local-x calculation and shared character-cell decoder. Coordinate
signals have explicit widths. This preserves the 20px cells, centering, colors,
and combinational output without adding pipeline latency or raster state.

## Footer result message

The result text is part of `credits_bet.v`, sharing its native-size cell decoder.
In RESULT, it displays `WIN 0005`, `WIN 0010`, up to `WIN 4000`, or `GAME OVER`
for a zero payout. The nine-cell field begins at (266,446); winning messages
use eight cells and a trailing blank. Both forms use the same fixed origin.
Text is yellow on the existing green background, with no panel or overlay.

A constant decoder maps the nine fixed awards directly to four decimal digits.
No additional decimal converter, font ROM, or result geometry module is used.
Keep the awards aligned with the core pay table. Unsupported nonzero awards
remain hidden. Reset and the next deal clear the result text. Cards remain
fully visible in RESULT; the hand-name message above them is unchanged.

## Card rectangles and indices

`card_faces.v` owns all five 110×154 white rectangles, starting at (23,261)
with a 121-pixel horizontal pitch. It selects the corresponding packed six-bit
card and requests corner glyphs through the single font in `vga.v`.
Suit encoding C/D/H/S = 0/1/2/3 maps directly to character IDs 37–40; diamonds
and hearts draw red, clubs and spades black.

Each corner reserves 24 pixels for the rank: `10` uses two 12px cells, while
single-character ranks are centered in that slot. Rank cells begin at local
y=8. The lower-right rank reverses both local coordinates to rotate 180 degrees.
Numbered cards have no corner suits, so every center pip corresponds to the card value.
Invalid ranks leave the white rectangle blank. Card selection first decodes
the slot and its origin, then computes local coordinates once. Coordinates and
pip indices have explicit bounded widths, with separate row/column validity
flags. Pip occupancy uses seven-row center and outer masks; left and right
columns share the outer mask. This changes only the logic representation,
not the card rectangles, pip placements, scaling, or rotations.

Aces show one ordinary 12px center suit. Ranks 2–10 use exactly that many 12px pips on
a three-column grid, with lower pips rotated. J/Q/K show ranks and 12px suits in both corners, plus a centered
48px rank letter as the portrait, with no center suit. Enlarged letters use integer scaling
of the same font bitmap, with no additional font ROM. Result text is in the footer and does not cover card artwork.

`test/test_cards.py` covers rectangle boundaries, all 52 cards, all five packed
positions, rank rotation, pip counts, enlarged glyph coordinates, and invalid
ranks. Native frame tests check rendered colors, corner rotation, center artwork,
and blank reset cards.

## Experimental implementation

See [the area experiment](vga-area-experiment.md) for this branch's removed
payout panel, shared geometry, gated converter banks, 18-bit working precision,
and production 0/5 units-digit specialization. The font interface and remaining
visible layout retain the baseline contract.
