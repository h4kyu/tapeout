`default_nettype none

// Payout-sheet panels and text requests. The shared font ROM lives in vga.v.
// Text addresses and glyph coordinates are valid when text_active is asserted.
module payout_table (
    input  wire [9:0] x,
    input  wire [9:0] y,
    output wire active,
    output reg [1:0] red,
    output reg [1:0] green,
    output reg [1:0] blue,
    output wire text_active,
    output wire numbers,
    output reg [3:0] text_row,
    output reg [3:0] text_column,
    output wire [3:0] glyph_x,
    output wire [3:0] glyph_y
);
    assign active = (x >= 23 && x < 617 && y >= 16 && y < 196);

    reg label_area;
    reg number_area;
    reg text_row_active;
    reg [3:0] row_offset;
    reg [3:0] column_offset;
    reg [7:0] local_y;
    reg [7:0] row_left;
    reg [4:0] row_pixel;
    reg [3:0] row_index;
    reg [7:0] local_x;
    reg [7:0] cell_left;

    // Constant-bounded loops synthesize to range checks, not clocked loops.
    // Each glyph is 12x12; text rows have six blank pixels between them.
    always @* begin
        local_y=0; row_left=0; row_pixel=0; row_index=0;
        text_row = 4'd0;
        text_column = 4'd0;
        text_row_active = 1'b0;
        label_area = 1'b0;
        number_area = 1'b0;
        row_offset = 0;
        column_offset = 0;
        local_x = 0;
        cell_left = 0;

        if (y >= 29 && y < 185) begin
            local_y=y-29;
            if (local_y >= 144) begin row_index=4'd8; row_left=8'd144; end
            else if (local_y >= 126) begin row_index=4'd7; row_left=8'd126; end
            else if (local_y >= 108) begin row_index=4'd6; row_left=8'd108; end
            else if (local_y >= 90) begin row_index=4'd5; row_left=8'd90; end
            else if (local_y >= 72) begin row_index=4'd4; row_left=8'd72; end
            else if (local_y >= 54) begin row_index=4'd3; row_left=8'd54; end
            else if (local_y >= 36) begin row_index=4'd2; row_left=8'd36; end
            else if (local_y >= 18) begin row_index=4'd1; row_left=8'd18; end
            row_pixel=local_y-row_left;
            if (row_pixel < 12) begin
                text_row=row_index;
                row_offset=row_pixel;
                text_row_active=1'b1;
            end
        end

        if (x >= 35 && x < 215) begin
            label_area=1'b1;
            local_x=x-35;
        end else if (x >= 555 && x < 603) begin
            number_area=1'b1;
            local_x=x-555;
        end
        if (label_area || number_area) begin
            if (local_x >= 168) begin text_column=4'd14; cell_left=8'd168; end
            else if (local_x >= 156) begin text_column=4'd13; cell_left=8'd156; end
            else if (local_x >= 144) begin text_column=4'd12; cell_left=8'd144; end
            else if (local_x >= 132) begin text_column=4'd11; cell_left=8'd132; end
            else if (local_x >= 120) begin text_column=4'd10; cell_left=8'd120; end
            else if (local_x >= 108) begin text_column=4'd9; cell_left=8'd108; end
            else if (local_x >= 96) begin text_column=4'd8; cell_left=8'd96; end
            else if (local_x >= 84) begin text_column=4'd7; cell_left=8'd84; end
            else if (local_x >= 72) begin text_column=4'd6; cell_left=8'd72; end
            else if (local_x >= 60) begin text_column=4'd5; cell_left=8'd60; end
            else if (local_x >= 48) begin text_column=4'd4; cell_left=8'd48; end
            else if (local_x >= 36) begin text_column=4'd3; cell_left=8'd36; end
            else if (local_x >= 24) begin text_column=4'd2; cell_left=8'd24; end
            else if (local_x >= 12) begin text_column=4'd1; cell_left=8'd12; end
            column_offset=local_x-cell_left;
        end
    end

    assign glyph_x = column_offset[3:0];
    assign glyph_y = row_offset[3:0];
    assign numbers = number_area;
    assign text_active = text_row_active && (label_area || number_area);

    wire black_inner=(x>=26 && x<614 && y>=19 && y<193);
    wire gray_panel=(x>=28 && x<487 && y>=21 && y<191);
    wire red_panel=(x>=491 && x<612 && y>=21 && y<191);
    wire yellow_border=active && !black_inner;
    always @* begin
        red={yellow_border || gray_panel || red_panel, yellow_border || red_panel};
        green={yellow_border || gray_panel, yellow_border};
        blue={gray_panel,1'b0};
    end

endmodule
