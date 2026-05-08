`timescale 1ns / 1ps

// Testbench for image_filter.v
// Verifies all four filter modes across a variety of input pixel values.
// Expected values are calculated analytically and checked against DUT output.
module tb_image_filter;

    reg  [1:0] filter_sw;
    reg  [3:0] r_in, g_in, b_in;
    wire [3:0] r_out, g_out, b_out;

    integer pass_count = 0;
    integer fail_count = 0;

    image_filter uut (
        .filter_sw(filter_sw),
        .r_in     (r_in),
        .g_in     (g_in),
        .b_in     (b_in),
        .r_out    (r_out),
        .g_out    (g_out),
        .b_out    (b_out)
    );

    // Apply inputs, wait for combinational settle, then compare
    task apply_and_check;
        input [1:0] sw;
        input [3:0] r, g, b;
        input [3:0] exp_r, exp_g, exp_b;
        input [7:0] test_id;
        begin
            filter_sw = sw;
            r_in = r; g_in = g; b_in = b;
            #10;
            if (r_out !== exp_r || g_out !== exp_g || b_out !== exp_b) begin
                $display("FAIL #%0d  sw=%b  in(%h,%h,%h)  got(%h,%h,%h)  exp(%h,%h,%h)",
                         test_id, sw, r, g, b,
                         r_out, g_out, b_out,
                         exp_r, exp_g, exp_b);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS #%0d  sw=%b  in(%h,%h,%h) -> out(%h,%h,%h)",
                         test_id, sw, r, g, b, r_out, g_out, b_out);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== image_filter testbench ===");

        // ----------------------------------------------------------------
        // Filter 0 — Raw pass-through (sw = 2'b00)
        // Expected: output == input for every channel
        // ----------------------------------------------------------------
        $display("-- Filter 0: Raw --");
        apply_and_check(2'b00, 4'hA, 4'h5, 4'h3,  4'hA, 4'h5, 4'h3,  1);
        apply_and_check(2'b00, 4'hF, 4'hF, 4'hF,  4'hF, 4'hF, 4'hF,  2);
        apply_and_check(2'b00, 4'h0, 4'h0, 4'h0,  4'h0, 4'h0, 4'h0,  3);
        apply_and_check(2'b00, 4'h1, 4'h2, 4'h3,  4'h1, 4'h2, 4'h3,  4);

        // ----------------------------------------------------------------
        // Filter 1 — Grayscale (sw = 2'b01)
        // Formula: gray = (5*R + 9*G + 2*B) >> 4  (unsigned, 4-bit result)
        // ----------------------------------------------------------------
        $display("-- Filter 1: Grayscale --");
        // Black → 0
        apply_and_check(2'b01, 4'h0, 4'h0, 4'h0,  4'h0, 4'h0, 4'h0,  5);
        // White → (5*15 + 9*15 + 2*15) = 240 = 0xF0; [7:4] = 0xF
        apply_and_check(2'b01, 4'hF, 4'hF, 4'hF,  4'hF, 4'hF, 4'hF,  6);
        // Pure red (15,0,0) → 5*15 = 75 = 0x4B; [7:4] = 0x4
        apply_and_check(2'b01, 4'hF, 4'h0, 4'h0,  4'h4, 4'h4, 4'h4,  7);
        // Pure green (0,15,0) → 9*15 = 135 = 0x87; [7:4] = 0x8
        apply_and_check(2'b01, 4'h0, 4'hF, 4'h0,  4'h8, 4'h8, 4'h8,  8);
        // Pure blue (0,0,15) → 2*15 = 30 = 0x1E; [7:4] = 0x1
        apply_and_check(2'b01, 4'h0, 4'h0, 4'hF,  4'h1, 4'h1, 4'h1,  9);
        // Mixed (8,8,8) → (5+9+2)*8 = 128 = 0x80; [7:4] = 0x8
        apply_and_check(2'b01, 4'h8, 4'h8, 4'h8,  4'h8, 4'h8, 4'h8, 10);
        // Mixed (4,8,4) → (5*4 + 9*8 + 2*4) = 20+72+8 = 100 = 0x64; [7:4] = 0x6
        apply_and_check(2'b01, 4'h4, 4'h8, 4'h4,  4'h6, 4'h6, 4'h6, 11);

        // ----------------------------------------------------------------
        // Filter 2 — Colour Inversion / Negative (sw = 2'b10)
        // Expected: each channel = ~input (bitwise NOT of 4 bits)
        // ----------------------------------------------------------------
        $display("-- Filter 2: Inversion --");
        apply_and_check(2'b10, 4'hF, 4'hF, 4'hF,  4'h0, 4'h0, 4'h0, 12);
        apply_and_check(2'b10, 4'h0, 4'h0, 4'h0,  4'hF, 4'hF, 4'hF, 13);
        // ~A=5  ~5=A  ~3=C
        apply_and_check(2'b10, 4'hA, 4'h5, 4'h3,  4'h5, 4'hA, 4'hC, 14);
        // ~1=E  ~2=D  ~4=B
        apply_and_check(2'b10, 4'h1, 4'h2, 4'h4,  4'hE, 4'hD, 4'hB, 15);
        // ~7=8  ~8=7  ~F=0
        apply_and_check(2'b10, 4'h7, 4'h8, 4'hF,  4'h8, 4'h7, 4'h0, 16);

        // ----------------------------------------------------------------
        // Filter 3 — Red Channel Isolation (sw = 2'b11)
        // Expected: r_out=r_in, g_out=0, b_out=0
        // ----------------------------------------------------------------
        $display("-- Filter 3: Red Isolation --");
        apply_and_check(2'b11, 4'hA, 4'h5, 4'h3,  4'hA, 4'h0, 4'h0, 17);
        apply_and_check(2'b11, 4'hF, 4'hF, 4'hF,  4'hF, 4'h0, 4'h0, 18);
        apply_and_check(2'b11, 4'h0, 4'h5, 4'h3,  4'h0, 4'h0, 4'h0, 19);
        apply_and_check(2'b11, 4'h7, 4'hF, 4'hA,  4'h7, 4'h0, 4'h0, 20);

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED — check output above");
        $finish;
    end

endmodule
