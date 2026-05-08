`timescale 1ns / 1ps

// Hardware image filter module for OV7670 camera pipeline.
// All three filters are purely combinational — zero added latency.
//
// filter_sw encoding:
//   2'b00 = Raw (pass-through)
//   2'b01 = Grayscale   — ITU-R BT.601 approximate: Y = (5R + 9G + 2B) / 16
//   2'b10 = Inversion   — bitwise NOT on every channel (colour negative)
//   2'b11 = Red-only    — zero out green and blue channels
module image_filter (
    input      [1:0] filter_sw,
    input      [3:0] r_in,
    input      [3:0] g_in,
    input      [3:0] b_in,
    output reg [3:0] r_out,
    output reg [3:0] g_out,
    output reg [3:0] b_out
);

    // Grayscale: weighted sum scaled to 4-bit output.
    // Weights 5/16, 9/16, 2/16 ≈ BT.601 coefficients 0.299, 0.587, 0.114.
    // Max value: (5+9+2)*15 = 240 = 0xF0 → [7:4] = 0xF. No overflow.
    wire [7:0] gray_sum = ({4'h0, r_in} * 8'd5)
                        + ({4'h0, g_in} * 8'd9)
                        + ({4'h0, b_in} * 8'd2);
    wire [3:0] gray = gray_sum[7:4];

    always @(*) begin
        case (filter_sw)
            2'b00: begin  // --- FILTER 0: Raw pass-through ---
                r_out = r_in;
                g_out = g_in;
                b_out = b_in;
            end
            2'b01: begin  // --- FILTER 1: Grayscale ---
                r_out = gray;
                g_out = gray;
                b_out = gray;
            end
            2'b10: begin  // --- FILTER 2: Colour Inversion (Negative) ---
                r_out = ~r_in;
                g_out = ~g_in;
                b_out = ~b_in;
            end
            2'b11: begin  // --- FILTER 3: Red Channel Isolation ---
                r_out = r_in;
                g_out = 4'h0;
                b_out = 4'h0;
            end
        endcase
    end

endmodule
