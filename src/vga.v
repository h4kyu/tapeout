`default_nettype none

module vga (
    input  wire [29:0] cards,
    input  wire [15:0] balance,
    input  wire [4:0]  held_cards,
    input  wire [2:0]  state,
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

    assign hsync = !((x >= 10'd656) && (x < 10'd752));
    assign vsync = !((y >= 10'd490) && (y < 10'd492));

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

    wire payout_active;
    wire [1:0] payout_red;
    wire [1:0] payout_green;
    wire [1:0] payout_blue;
    wire payout_text_active;
    wire payout_numbers;
    wire [3:0] payout_text_row;
    wire [3:0] payout_text_column;
    wire [3:0] payout_glyph_x;
    wire [3:0] payout_glyph_y;

    payout_table payout_sheet (
        .x(x), .y(y), .active(payout_active),
        .red(payout_red), .green(payout_green), .blue(payout_blue),
        .text_active(payout_text_active), .numbers(payout_numbers),
        .text_row(payout_text_row), .text_column(payout_text_column),
        .glyph_x(payout_glyph_x), .glyph_y(payout_glyph_y)
    );

    wire [5:0] table_character;
    payout_characters table_words (
        .numbers(payout_numbers), .text_row(payout_text_row),
        .column(payout_text_column), .character(table_character)
    );
    wire [5:0] font_character = table_character;
    wire [3:0] font_row = payout_glyph_y;
    wire [3:0] font_column = payout_glyph_x;
    wire font_active = payout_text_active;
    wire [11:0] font_pixels;
    wire text_pixel = font_active && (font_column < 4'd12)
                      && font_pixels[4'd11 - font_column];
    font_rom text_font (
        .character(font_character), .row(font_row), .pixels(font_pixels)
    );

    always @* begin
        red   = 2'b00;
        green = 2'b00;
        blue  = 2'b00;

        if (visible) begin
            // Green background
            green = 2'b10;

            // Composite the payout panels over the background and cards.
            if (payout_active) begin
                red   = payout_red;
                green = payout_green;
                blue  = payout_blue;
            end

            // Text is drawn last so glyph pixels overwrite the table panels.
            if (text_pixel) begin
                red   = 2'b11;
                green = 2'b11;
                blue  = 2'b11;
            end
        end
    end

endmodule
