`default_nettype none

// cards as {suit[1:0], rank[3:0]}, rank 2..14
// candidate is consumed on every prng_ready && dealer_ready edge
module poker_dealer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire draw_mode,
    input wire [4:0] hold_mask,
    input wire [5:0] candidate,
    input wire prng_ready,
    output wire dealer_ready,
    output reg done,
    output reg [29:0] cards,
    output reg [51:0] dealt_mask
);

    reg busy;
    reg [4:0] held;
    reg [2:0] slot;
    // Keep the original hand during a draw; cards itself holds the currently
    // displayed hand, including accepted replacements. Their union is exactly
    // the round's used-card set, without duplicating ten independent entries.
    wire [29:0] original_cards;
    reg original_valid;
    reg candidate_used;
    integer i;
    wire valid_rank = candidate[3:0] >= 4'd2 && candidate[3:0] <= 4'd14;
    assign dealer_ready = busy && !held[slot];

    always @* begin
        candidate_used = 1'b0;
        // Preserve the inspection interface without storing a second mask.
        // This decode is removed when dealt_mask is unconnected at the top level.
        dealt_mask = 52'b0;
        for (i = 0; i < 5; i = i + 1) begin
            // Empty slots contain zero, which cannot equal an accepted rank.
            if (candidate == cards[i*6 +: 6]) candidate_used = 1'b1;
            if (cards[i*6 +: 4] >= 2 && cards[i*6 +: 4] <= 14) begin
                dealt_mask[cards[i*6+4 +: 2] * 13 + cards[i*6 +: 4] - 2] = 1'b1;
            end
            if (original_valid) begin
                if (candidate == original_cards[i*6 +: 6]) candidate_used = 1'b1;
                dealt_mask[original_cards[i*6+4 +: 2] * 13 + original_cards[i*6 +: 4] - 2] = 1'b1;
            end
        end
    end

    // cards does not change on a start-draw edge, and busy inhibits a
    // second start before the high phase ends: this bank's input is stable.
    stable_bank initial_hand_snapshot(.clk(clk),.enable(start && !busy && draw_mode),
                                     .data(cards),.value(original_cards));

    wire new_hand=start && !busy && !draw_mode;
    wire accept_card=busy && !held[slot] && prng_ready && valid_rank && !candidate_used;
    generate for(genvar bank=0;bank<5;bank=bank+1) begin:card_storage
        wire bank_clock;
        clock_gate bank_gate(.clk(clk),.enable(new_hand || (accept_card && slot==bank)),.gated_clk(bank_clock));
        always @(posedge bank_clock or negedge rst_n) begin
            if(!rst_n) cards[bank*6 +:6]<=0;
            else cards[bank*6 +:6]<=new_hand ? 6'd0 : candidate;
        end
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            original_valid <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            held <= 5'b0;
            slot <= 3'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                slot <= 3'd0;
                held <= draw_mode ? hold_mask : 5'b0;
                if (!draw_mode) begin
                    // The original-hand snapshot is ignored throughout a fresh deal.
                    original_valid <= 1'b0;
                end else begin
                    original_valid <= 1'b1;
                end
            end else if (busy) begin
                if (held[slot]) begin
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end else if (prng_ready && valid_rank && !candidate_used) begin
                    if (slot == 3'd4) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else slot <= slot + 3'd1;
                end
            end
        end
    end
endmodule

// Pulse-open storage for a bank whose D input is stable for the entire armed
// high phase. The low-phase enable latch prevents late high-phase pulses.
// Caller must prove input stability; this is not a general flip-flop replacement.
module stable_bank #(parameter WIDTH=30) (
    input wire clk, input wire enable, input wire [WIDTH-1:0] data,
    output wire [WIDTH-1:0] value
);
    wire armed;
`ifdef SYNTHESIS
    gf180mcu_fd_sc_mcu7t5v0__latq_1 enable_latch(.D(enable),.E(~clk),.Q(armed));
    for(genvar bit_index=0;bit_index<WIDTH;bit_index=bit_index+1) begin:bits
        gf180mcu_fd_sc_mcu7t5v0__latq_1 data_latch(.D(data[bit_index]),.E(clk && armed),.Q(value[bit_index]));
    end
`else
    /* verilator lint_off LATCH */
    reg armed_model;
    reg [WIDTH-1:0] value_model;
    always @* if(!clk) armed_model=enable;
    always @* if(clk && armed_model) value_model=data;
    assign armed=armed_model;
    assign value=value_model;
    /* verilator lint_on LATCH */
`endif
endmodule

// Integrated clock gate: the enable is latched while the root clock is low.
module clock_gate(input wire clk,input wire enable,output wire gated_clk);
`ifdef SYNTHESIS
    gf180mcu_fd_sc_mcu7t5v0__icgtp_1 gate_cell(.CLK(clk),.E(enable),.TE(1'b0),.Q(gated_clk));
`else
    /* verilator lint_off LATCH */
    reg armed;
    always @* if(!clk) armed=enable;
    assign gated_clk=clk && armed;
    /* verilator lint_on LATCH */
`endif
endmodule
