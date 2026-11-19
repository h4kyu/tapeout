`default_nettype none

// core digital logic implementation
module poker_core #(parameter SPACED_CREDITS=0) (
    output wire [19:0] credit_digits,
    input wire clk,
    input wire rst_n,
    input wire deal_draw_pulse, 
    input wire [4:0] hold_mask, 
    input wire [5:0] candidate,
    input wire prng_ready,
    output wire dealer_ready,
    output wire [29:0] cards,
    output wire [51:0] dealt_mask,
    output reg [4:0] held_cards,
    output reg [2:0] state,
    output reg [15:0] balance,
    output wire [3:0] hand_category,
    output reg [3:0] result_category,
    output reg [11:0] result_payout,
    output wire can_deal
);

    localparam IDLE = 3'd0, 
               DEALING = 3'd1, 
               HOLD = 3'd2,
               DRAWING = 3'd3, 
               EVALUATE = 3'd4, 
               RESULT = 3'd5;

    wire dealer_done;
    wire [3:0] category;
    wire [11:0] payout;
    // Expose the existing evaluator for live display; no second evaluator.
    // The dealer guarantees unique valid cards once the initial hand is full.
    // During its initial fill, the old evaluator returned zero for empty slots.
    assign hand_category = (state==IDLE || (state==DEALING && !dealer_done)) ? 4'd0 : category;
    wire [16:0] balance_change = start_deal ? 17'h1fffb : {5'b0,payout};
    wire [16:0] credited_balance = {1'b0,balance} + balance_change;
    wire funded;
    assign can_deal = (state == IDLE || state == RESULT) && funded;
    wire start_deal = deal_draw_pulse && can_deal;
    wire start_draw = deal_draw_pulse && state == HOLD;

    poker_dealer dealer (
        .clk(clk), .rst_n(rst_n), .start(start_deal || start_draw),
        .draw_mode(start_draw), .hold_mask(hold_mask),
        .candidate(candidate), .prng_ready(prng_ready),
        .dealer_ready(dealer_ready),
        .done(dealer_done), .cards(cards), .dealt_mask(dealt_mask)
    );
    
    poker_evaluator #(.DEALER_VALIDATED(1)) evaluator (.cards(cards), .category(category), .payout(payout));

    // Only latch the final category; its fixed award needs no separate storage.
    always @* begin
        case (result_category)
            4'd1: result_payout = 12'd5;
            4'd2: result_payout = 12'd10;
            4'd3: result_payout = 12'd15;
            4'd4: result_payout = 12'd20;
            4'd5: result_payout = 12'd30;
            4'd6: result_payout = 12'd45;
            4'd7: result_payout = 12'd125;
            4'd8: result_payout = 12'd250;
            4'd9: result_payout = 12'd4000;
            default: result_payout = 12'd0;
        endcase
    end

    generate if (SPACED_CREDITS) begin : decimal_account
        wire [15:0] observed_balance;
        poker_wallet wallet(.clk(clk), .rst_n(rst_n), .bet(start_deal),
            .award(state == EVALUATE), .category(category), .result_category(result_category), .result(state == RESULT), .funded(funded),
            .balance(observed_balance), .displayed(credit_digits));
        always @* balance = observed_balance;
    end else begin : binary_account
        assign funded = balance >= 16'd5;
        assign credit_digits = 0;
        wire balance_clock;
        clock_gate balance_gate(.clk(clk),.enable(start_deal || state==EVALUATE),.gated_clk(balance_clock));
        always @(posedge balance_clock or negedge rst_n) begin
            if(!rst_n) balance<=16'd100;
            else balance<=(state==EVALUATE && credited_balance[16]) ? 16'hffff : credited_balance[15:0];
        end

    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            held_cards <= 5'b0;
            result_category <= 4'b0;
        end else begin
            case (state)
                IDLE, RESULT: if (start_deal) begin
                    held_cards <= 5'b0;
                    result_category <= 4'b0;
                    state <= DEALING;
                end
                DEALING: if (dealer_done) state <= HOLD;
                HOLD: begin
                    held_cards <= hold_mask;
                    if (start_draw) state <= DRAWING;
                end
                DRAWING: if (dealer_done) state <= EVALUATE;
                EVALUATE: begin
                    result_category <= category;
                    state <= RESULT;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

// Keep the committed balance in the same decimal representation used on screen.
// An action takes effect immediately for gameplay. Seventeen clocks later the
// pending amount commits, matching the original converter's atomic display.
module poker_wallet(
    input wire clk, rst_n, bet, award,
    input wire [3:0] category, result_category,
    input wire result,
    output wire funded, output wire [15:0] balance, output wire [19:0] displayed
);
    reg [4:0] remaining;
    // The controller stays in RESULT throughout a delayed award commit.
    // After a wager it cannot reach RESULT before the next accepted press.
    wire [3:0] operation = result ? result_category : 4'd10;
    reg [16:0] account; // Four full decimal digits plus the 0/5 units bit
    wire spend = operation == 10;
    wire units = spend || operation == 1 || operation == 3 ||
                 operation == 6 || operation == 7;
    reg [15:0] tens;
    always @* case (operation)
        2,3: tens=16'h0001;
        4: tens=16'h0002;
        5: tens=16'h0003;
        6: tens=16'h0004;
        7: tens=16'h0012;
        8: tens=16'h0025;
        9: tens=16'h0400;
        10: tens=16'h9999; // Decimal complement for subtracting five
        default: tens=0;
    endcase
    wire [4:0] carry;
    assign carry[0] = account[0] && units;
    wire [16:0] sum;
    assign sum[0] = account[0] ^ units;
    for (genvar i=0; i<4; i=i+1) begin : digits
        wire [4:0] raw = {1'b0,account[4*i+1 +: 4]} + tens[4*i +: 4] + carry[i];
        assign carry[i+1] = raw >= 10;
        assign sum[4*i+1 +: 4] = raw[3:0] + (carry[i+1] ? 4'd6 : 0);
    end
    localparam [16:0] MAX_CREDITS = {16'h6553,1'b1};
    wire [16:0] adjusted = sum > MAX_CREDITS ? MAX_CREDITS : sum;
    wire pending = remaining != 0;
    wire [16:0] effective = pending ? adjusted : account;
    assign funded = !pending ? |account : !spend || (|account[16:1]);
    // Binary observation for the game API. The display uses the decimal
    // port directly, so these constant products drop out in the chip build.
    assign balance = effective[16:13] * 16'd10000 + effective[12:9] * 16'd1000
                   + effective[8:5] * 16'd100 + effective[4:1] * 16'd10
                   + (effective[0] ? 16'd5 : 0);
    assign displayed = {account[16:1],1'b0,account[0],1'b0,account[0]};
    wire commit_clock;
    clock_gate account_gate(.clk(clk), .enable(remaining == 1), .gated_clk(commit_clock));
    always @(posedge commit_clock or negedge rst_n) begin
        if (!rst_n) account <= {16'h0010,1'b0};
        else account <= adjusted;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) remaining <= 0;
        else if (bet || (award && category != 0)) begin
            remaining <= 17;
        end else if (pending) remaining <= remaining - 1'b1;
    end
endmodule
