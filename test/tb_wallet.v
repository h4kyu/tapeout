`timescale 1ns/1ps
// Exhaust the reachable balances and transitions of the physical decimal bank.
module tb_wallet;
    reg clk=0, rst_n=1, bet=0, award=0, result=0;
    reg [3:0] category=0, result_category=0;
    wire funded;
    wire [15:0] balance;
    wire [19:0] displayed;
    poker_wallet wallet(.*);

    function [19:0] decimal_digits(input integer amount);
        integer i;
        begin
            for (i=0; i<5; i=i+1) begin
                decimal_digits[i*4 +: 4] = amount % 10;
                amount = amount / 10;
            end
        end
    endfunction

    task tick;
        begin #1; clk=1; #1; clk=0; #1; end
    endtask

    integer awards [0:10];
    integer prior, op, expected, elapsed;
    reg [19:0] original_digits, final_digits;
    initial begin
        awards[0]=0; awards[1]=5; awards[2]=10; awards[3]=15;
        awards[4]=20; awards[5]=30; awards[6]=45; awards[7]=125;
        awards[8]=250; awards[9]=4000; awards[10]=-5;
        #1; rst_n=0; tick(); rst_n=1;
        for (prior=0; prior<=65535; prior=prior+5) begin
            original_digits=decimal_digits(prior);
            for (op=0; op<=10; op=op+1) if (op!=10 || prior>=5) begin
                // Seed the committed bank between transactions, then use the
                // same action and result signals that the controller supplies.
                wallet.account={original_digits[19:4],original_digits[0]};
                result=0; bet=op==10; award=!bet; category=bet ? 0 : op;
                #1;
                if (balance!==prior || funded!==(prior>=5)) $fatal(1,"initial");
                tick();
                result=award; result_category=category; bet=0; award=0;
                expected=prior+awards[op];
                if(expected>65535) expected=65535;
                final_digits=decimal_digits(expected);
                for(elapsed=0; elapsed<=17; elapsed=elapsed+1) begin
                    #1;
                    if(balance!==expected || funded!==(expected>=5) ||
                       displayed!==(elapsed<17 ? original_digits : final_digits))
                        $fatal(1,"balance=%d op=%d clock=%d",prior,op,elapsed);
                    if(elapsed<17) tick();
                end
            end
        end
        // An asynchronous reset cancels an in-flight update.
        award=1; category=9; tick(); #1; rst_n=0; #1;
        if(balance!==100 || displayed!==20'h00100) $fatal(1,"reset");
        $display("PASS: every reachable balance, every legal award/wager, 17-clock visibility, reset");
        $finish;
    end
endmodule
