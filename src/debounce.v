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

    // Primitive 19-bit recurrence for the production delay. Start at zero
    // after each bounce. The terminal word is reached after 499999 shifts.
    localparam USE_LFSR = DEBOUNCE_CYCLES == 500000;
    wire [COUNTER_WIDTH-1:0] next_count;
    if (USE_LFSR) begin : production_delay
        wire feedback = ~^(counter & 19'h40023);
        assign next_count = {counter[17:0], feedback};
    end else begin : binary_delay
        assign next_count = counter - 1'b1;
    end
    localparam [COUNTER_WIDTH-1:0] INITIAL_COUNT = USE_LFSR ? 0 : COUNT_END;
    localparam [COUNTER_WIDTH-1:0] TERMINAL_COUNT = USE_LFSR ? 19'h4d962 : 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter         <= INITIAL_COUNT;
            button_out      <= 1'b0;
            button_in_sync1 <= 1'b0;
            button_in_sync2 <= 1'b0;
        end else begin
            // sync twice to let metastable register settle
            button_in_sync1 <= button_in;
            button_in_sync2 <= button_in_sync1;

            // Count down so the terminal check is a zero comparison.
            if (button_in_sync2 == button_out)
                counter <= INITIAL_COUNT;
            else if (counter == TERMINAL_COUNT) begin
                counter <= INITIAL_COUNT;
                button_out <= button_in_sync2;
            end else
                counter <= next_count;
        end
    end

endmodule
