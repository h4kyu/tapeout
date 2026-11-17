module debounce #(
    parameter integer DEBOUNCE_CYCLES = 500_000 // 20 ms
) (
    input  wire button_in,
    output reg  button_out,
    input  wire clk,
    input  wire rst_n
);

    // Bitsize of the counter
    localparam integer COUNTER_WIDTH = (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;
    // Reload value: accept a change after DEBOUNCE_CYCLES stable clocks.
    localparam [COUNTER_WIDTH - 1:0] COUNT_END = COUNTER_WIDTH'(DEBOUNCE_CYCLES - 1);

    reg [COUNTER_WIDTH - 1:0] counter;

    // in case of metastability
    reg button_in_sync1;
    reg button_in_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter         <= COUNT_END;
            button_out      <= 1'b0;
            button_in_sync1 <= 1'b0;
            button_in_sync2 <= 1'b0;
        end else begin
            // sync twice to let metastable register settle
            button_in_sync1 <= button_in;
            button_in_sync2 <= button_in_sync1;

            // Count down so the terminal check is a zero comparison.
            if (button_in_sync2 == button_out)
                counter <= COUNT_END;
            else if (counter == '0) begin
                counter <= COUNT_END;
                button_out <= button_in_sync2;
            end else
                counter <= counter - 1'b1;
        end
    end

endmodule
