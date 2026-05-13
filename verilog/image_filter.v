`timescale 1ns / 1ps

module image_filter (
    input      [ 1:0] filter_sw,
    input      [11:0] pixel_in,
    output reg [11:0] pixel_out
);

    wire [3:0] r_in = pixel_in[11:8];
    wire [3:0] g_in = pixel_in[7:4];
    wire [3:0] b_in = pixel_in[3:0];
    wire [3:0] gray = (r_in >> 2) + (g_in >> 1) + (b_in >> 2);
    wire [3:0] thresh = (gray > 4'd7) ? 4'hF : 4'h0;

    always @(*) begin
        case (filter_sw)
            2'b00: begin // Raw feed
                pixel_out = {r_in, g_in, b_in};
            end
            2'b01: begin // Grayscale
                pixel_out = {gray, gray, gray};
            end
            2'b10: begin // Binary threshold
                pixel_out = {thresh, thresh, thresh};
            end
            2'b11: begin // Red isolation
                pixel_out = {r_in, 4'h0, 4'h0};
            end
            default: begin
                pixel_out = 12'h000;
            end
        endcase
    end

endmodule
