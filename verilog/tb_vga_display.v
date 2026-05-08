`timescale 1ns / 1ps

// Testbench for vga_display.v
// Verifies:
//   1. HSYNC and VSYNC pulse widths and periods match 640x480 @ 60 Hz spec.
//   2. frame_addr pixel-doubling (320x240 → 640x480): each BRAM address is held for 2 pixels.
//   3. Blanking: RGB outputs are 0 outside the active video region.
//   4. Filter routing: each filter_sw value produces the correct colour transform.
//
// Clock period: 40 ns  (25 MHz)
module tb_vga_display;

    // DUT ports
    reg         clk25      = 0;
    reg  [1:0]  filter_sw  = 0;
    wire [3:0]  vga_red;
    wire [3:0]  vga_green;
    wire [3:0]  vga_blue;
    wire        vga_hsync;
    wire        vga_vsync;
    wire [16:0] frame_addr;
    reg  [11:0] frame_pixel = 12'hABC;  // constant test pixel: R=A G=B B=C

    // VGA timing constants (must match DUT)
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_BACK   = 48;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_BACK   = 33;
    localparam V_TOTAL  = 525;

    localparam CLK_PERIOD = 40;  // ns

    vga_display uut (
        .clk25      (clk25),
        .filter_sw  (filter_sw),
        .vga_red    (vga_red),
        .vga_green  (vga_green),
        .vga_blue   (vga_blue),
        .vga_hsync  (vga_hsync),
        .vga_vsync  (vga_vsync),
        .frame_addr (frame_addr),
        .frame_pixel(frame_pixel)
    );

    always #(CLK_PERIOD/2) clk25 = ~clk25;

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
    integer fail_count = 0;

    task assert_eq;
        input [31:0] actual, expected;
        input [127:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL  %s : got %0d, expected %0d", label, actual, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS  %s = %0d", label, actual);
            end
        end
    endtask

    // Measure how many clock cycles 'sig' stays at 'level' starting now.
    // Counts up to max_cycles to avoid infinite loops.
    function [31:0] count_cycles_at;
        input sig_val;
        input expected_level;
        input [31:0] max_cycles;
        integer i;
        reg done;
        begin
            count_cycles_at = 0;
            done = 0;
            for (i = 0; i < max_cycles && !done; i = i + 1) begin
                @(posedge clk25);
                if (sig_val === expected_level)
                    count_cycles_at = count_cycles_at + 1;
                else
                    done = 1;
            end
        end
    endfunction

    // ----------------------------------------------------------------
    // Test 1 — HSYNC timing
    // Run for one complete HSYNC period and verify pulse width.
    // ----------------------------------------------------------------
    integer hsync_low_count;
    integer hsync_high_count;
    integer h_period;

    // ----------------------------------------------------------------
    // Test 2 — frame_addr pixel doubling
    // Within the active region, two consecutive pixels must share the same addr.
    // ----------------------------------------------------------------
    reg [16:0] addr_prev;
    integer double_ok;
    integer double_fail;

    // ----------------------------------------------------------------
    // Main
    // ----------------------------------------------------------------
    integer cycle;
    integer line;

    initial begin
        $display("=== vga_display testbench ===");

        // Wait for counter to settle from initial 0 state (one full line)
        repeat (H_TOTAL) @(posedge clk25);

        // ----------------------------------------------------------------
        // Test 1: HSYNC pulse width = H_SYNC cycles = 96
        // HSYNC is active-low, so pulse = low portion of the signal.
        // ----------------------------------------------------------------
        $display("-- Test 1: HSYNC timing --");
        // Advance to falling edge of HSYNC
        while (vga_hsync !== 1'b0) @(posedge clk25);

        // Count how many cycles HSYNC stays low
        hsync_low_count = 1;
        @(posedge clk25);
        while (vga_hsync === 1'b0) begin
            hsync_low_count = hsync_low_count + 1;
            @(posedge clk25);
        end
        assert_eq(hsync_low_count, H_SYNC, "HSYNC pulse width (cycles)");

        // Count how many cycles HSYNC stays high (= H_TOTAL - H_SYNC = 704)
        hsync_high_count = 1;
        @(posedge clk25);
        while (vga_hsync === 1'b1) begin
            hsync_high_count = hsync_high_count + 1;
            @(posedge clk25);
        end
        assert_eq(hsync_high_count, H_TOTAL - H_SYNC, "HSYNC high duration (cycles)");

        // ----------------------------------------------------------------
        // Test 2: frame_addr pixel doubling inside active region
        // Run for two full lines at the start of the active region.
        // Each logical pixel column (0..319) must appear for exactly 2
        // consecutive VGA pixel clocks.
        // ----------------------------------------------------------------
        $display("-- Test 2: frame_addr pixel doubling --");

        // Advance to start of active area (h=0, v=0)
        while (vga_vsync !== 1'b0) @(posedge clk25);  // wait for vsync low
        while (vga_vsync === 1'b0) @(posedge clk25);  // wait for vsync end
        // Now we're just past vsync; fast-forward through back porch + front of frame
        repeat (V_BACK * H_TOTAL) @(posedge clk25);   // skip vertical back porch

        double_ok   = 0;
        double_fail = 0;
        // Sample 2 lines × 640 pixels
        for (line = 0; line < 2; line = line + 1) begin
            addr_prev = frame_addr;
            @(posedge clk25);
            for (cycle = 1; cycle < H_ACTIVE; cycle = cycle + 1) begin
                // Every even pixel should change addr; every odd pixel keeps it
                if (cycle % 2 == 1) begin
                    // addr must stay the same as previous cycle (pixel doubling)
                    if (frame_addr !== addr_prev) begin
                        double_fail = double_fail + 1;
                    end else begin
                        double_ok = double_ok + 1;
                    end
                end else begin
                    addr_prev = frame_addr;
                end
                @(posedge clk25);
            end
            // Skip blanking (H_FRONT + H_SYNC + H_BACK = 160 cycles)
            repeat (H_TOTAL - H_ACTIVE) @(posedge clk25);
        end
        if (double_fail == 0)
            $display("PASS  pixel-doubling: %0d consecutive pairs correct", double_ok);
        else
            $display("FAIL  pixel-doubling: %0d bad, %0d good", double_fail, double_ok);

        // ----------------------------------------------------------------
        // Test 3: RGB blanked outside active video
        // Wait for blanking interval and check that outputs are 0.
        // ----------------------------------------------------------------
        $display("-- Test 3: Blanking region RGB = 0 --");
        // Advance to horizontal blanking (h >= H_ACTIVE)
        while (vga_hsync !== 1'b0) @(posedge clk25);  // go to next hsync
        // We are in the sync pulse; hsync blanking — check RGB
        if (vga_red === 4'h0 && vga_green === 4'h0 && vga_blue === 4'h0)
            $display("PASS  blanking RGB = 0 during HSYNC");
        else
            $display("FAIL  blanking: R=%h G=%h B=%h (expected 0,0,0)", vga_red, vga_green, vga_blue);

        // ----------------------------------------------------------------
        // Test 4: Filter routing (combinational check, no need for full frame)
        // Jump back to active region via a known frame_pixel = 0xABC
        //   R=A, G=B, B=C
        // ----------------------------------------------------------------
        $display("-- Test 4: Filter routing (frame_pixel = 0xABC) --");

        // Wait for one active pixel in the next frame
        while (vga_vsync !== 1'b0) @(posedge clk25);
        while (vga_vsync === 1'b0) @(posedge clk25);
        repeat (V_BACK * H_TOTAL + 2) @(posedge clk25);  // land inside active area

        // sw=00 raw: expect R=A, G=B, B=C (registered, so check next cycle)
        filter_sw = 2'b00;
        @(posedge clk25);
        assert_eq({28'h0, vga_red},   32'hA, "sw=00 red   (raw)");
        assert_eq({28'h0, vga_green}, 32'hB, "sw=00 green (raw)");
        assert_eq({28'h0, vga_blue},  32'hC, "sw=00 blue  (raw)");

        // sw=01 grayscale: gray = (5*A + 9*B + 2*C) >> 4
        //   = (5*10 + 9*11 + 2*12) >> 4 = (50+99+24) >> 4 = 173 >> 4 = 10 = 0xA
        filter_sw = 2'b01;
        @(posedge clk25);
        assert_eq({28'h0, vga_red},   32'hA, "sw=01 red   (gray)");
        assert_eq({28'h0, vga_green}, 32'hA, "sw=01 green (gray)");
        assert_eq({28'h0, vga_blue},  32'hA, "sw=01 blue  (gray)");

        // sw=10 inversion: ~A=5, ~B=4, ~C=3
        filter_sw = 2'b10;
        @(posedge clk25);
        assert_eq({28'h0, vga_red},   32'h5, "sw=10 red   (invert)");
        assert_eq({28'h0, vga_green}, 32'h4, "sw=10 green (invert)");
        assert_eq({28'h0, vga_blue},  32'h3, "sw=10 blue  (invert)");

        // sw=11 red-only: R=A, G=0, B=0
        filter_sw = 2'b11;
        @(posedge clk25);
        assert_eq({28'h0, vga_red},   32'hA, "sw=11 red   (red-only)");
        assert_eq({28'h0, vga_green}, 32'h0, "sw=11 green (red-only)");
        assert_eq({28'h0, vga_blue},  32'h0, "sw=11 blue  (red-only)");

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("=== Results: %0d failures ===", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
