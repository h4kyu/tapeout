`default_nettype none

module prng (
    input  wire [7:0] seed,
    output wire [5:0] rand_num,
    output reg prng_ready,
    input  wire clk,
    input  wire rst_n
);

    reg [7:0] lfsr;
    wire feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    assign rand_num = lfsr[5:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Load the seed on the first clock after reset,
            // asynchronous reset hardware requires a constant reset value.
            lfsr <= 8'b0;
            prng_ready <= 1'b0;
        end else if (prng_ready == 1'b0) begin
            lfsr <= (seed == 8'b0) ? 8'h01 : seed;
            prng_ready <= 1'b1;
        end else begin
            lfsr <= {lfsr[6:0], feedback};
        end
    end

endmodule