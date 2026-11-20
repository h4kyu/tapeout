// Both tops use their production 500,000-clock debounce and the same inputs.
module production_equivalence;
    reg clk=0, rst_n=1;
    reg [7:0] ui=0, seed=42;
    wire [7:0] golden_pins, actual_pins;
    gold_tt_um_h4kyu_video_poker reference_chip(.ui_in(ui), .uio_in(seed),
        .uo_out(golden_pins), .uio_out(), .uio_oe(), .ena(1'b1), .clk(clk), .rst_n(rst_n));
    tt_um_h4kyu_video_poker chip(.ui_in(ui), .uio_in(seed), .uo_out(actual_pins),
        .uio_out(), .uio_oe(), .ena(1'b1), .clk(clk), .rst_n(rst_n));

    integer cycles=0, presses=0, awards=0;
    task compare_outputs;
        if ({golden_pins, reference_chip.cards, reference_chip.held_cards,
             reference_chip.state, reference_chip.balance, reference_chip.hand_category,
             reference_chip.result_payout, reference_chip.deal_draw_pulse,
             reference_chip.game_vga_renderer.footer.displayed_digits} !==
            {actual_pins, chip.cards, chip.held_cards, chip.state, chip.balance,
             chip.hand_category, chip.result_payout, chip.deal_draw_pulse, chip.credit_digits})
            $fatal(1, "Mismatch on cycle %d, clk=%b", cycles, clk);
    endtask

    task clocks(input integer count);
        repeat (count) begin
            #1; compare_outputs();
            if (chip.deal_draw_pulse) presses++;
            if (chip.state == 4) awards++;
            clk=1; #1; compare_outputs(); clk=0; cycles++;
        end
    endtask

    initial begin
        #1; rst_n=0; clocks(3); rst_n=1;
        for (integer round=0; round<6; round++) begin
            // Bounce one cycle short of acceptance, then deal and draw.
            ui={3'b001, 5'(round*7)}; clocks(499999);
            ui[5]=0; clocks(10);
            ui[5]=1; clocks(500050); ui[5]=0; clocks(500050);
            ui[5]=1; clocks(500050); ui[5]=0; clocks(500050);
            if (round==2) begin rst_n=0; seed=91; clocks(2); rst_n=1; end
        end
        if (presses!=12 || awards!=6) $fatal(1, "Missed gameplay coverage");
        $display("PASS: %d production cycles, both clock phases, %d completed draws", cycles, awards);
        $finish;
    end
endmodule
