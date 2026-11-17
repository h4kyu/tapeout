`timescale 1ns/1ps
// Exhaustive conversion and commit timing, including the production 0/5 digit.
module tb_credits_exhaustive;
    reg clk=0;
    always #20 clk=~clk;
    reg rst_n=0;
    reg [15:0] balance=100;
    reg [9:0] x=555;
    wire [5:0] character;
    wire [4:0] pixel_x;
    integer amount, column, divisor;
    reg [19:0] expected, previous=20'h00100;
    credits_bet general_digits(.clk(clk),.rst_n(rst_n),.x(x),.y(10'd446),
        .balance(balance),.state(3'd0),.payout(12'd0),.character(character),.pixel_x(pixel_x));
    credits_bet #(.MULTIPLE_OF_FIVE(1)) game_digits(.clk(clk),.rst_n(rst_n),.x(x),.y(10'd446),
        .balance(balance),.state(3'd0),.payout(12'd0));
    initial begin
        repeat(2) @(negedge clk);
        rst_n=1;
        for(amount=0;amount<65536;amount=amount+1) begin
            @(negedge clk);
            balance=amount;
            repeat(16) @(negedge clk);
            if(general_digits.displayed_digits !== previous)
                $fatal(1,"Credits changed before the 17th clock: %d",amount);
            @(negedge clk);
            expected=((amount/10000)<<16)|(((amount/1000)%10)<<12)|
                     (((amount/100)%10)<<8)|(((amount/10)%10)<<4)|(amount%10);
            if(general_digits.displayed_digits !== expected)
                $fatal(1,"Wrong conversion: %d",amount);
            if(amount%5==0 && game_digits.displayed_digits !== expected)
                $fatal(1,"Wrong production conversion: %d",amount);
            divisor=10000;
            for(column=0;column<5;column=column+1) begin
                x=555+12*column;
                #1;
                if(character !== ((amount/divisor)%10)+1 || pixel_x !== 0)
                    $fatal(1,"Wrong glyph ID/phase: balance %d column %d",amount,column);
                divisor=divisor/10;
            end
            previous=expected;
        end
        $display("PASS: 65536 generic and 13108 production balances; 17-clock commits and glyph IDs");
        $finish;
    end
endmodule
