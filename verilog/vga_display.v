`timescale 1ns / 1ps

module vga_display (
    input            clk25,
    input      [1:0] filter_sw,
    output reg [3:0] vga_red,
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,
    output reg       vga_hsync,
    output reg       vga_vsync,
    output reg [16:0] frame_addr,
    input      [11:0] frame_pixel
);

    // VGA 640x480 @ 60Hz Timing Constants
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

    reg [9:0] r_h_cnt = 0;
    reg [9:0] r_v_cnt = 0;
    wire      active_video;

    wire [9:0] next_h_cnt;
    wire [9:0] next_v_cnt;
    wire       next_active_video;
    wire [16:0] next_frame_addr;

    reg [11:0] r_frame_pixel = 12'b0;
    reg         r_active_video = 1'b0;

    // Filter Logic setup
    wire [3:0] r_in = r_frame_pixel[11:8];
    wire [3:0] g_in = r_frame_pixel[7:4];
    wire [3:0] b_in = r_frame_pixel[3:0];

    // Grayscale (R/4 + G/2 + B/4)
    wire [3:0] gray = (r_in >> 2) + (g_in >> 1) + (b_in >> 2);
    // Binary Threshold
    wire [3:0] thresh = (gray > 4'd7) ? 4'hF : 4'h0;

    // Counters
    always @(posedge clk25) begin
        if (r_h_cnt < H_TOTAL - 1) begin
            r_h_cnt <= r_h_cnt + 1;
        end else begin
            r_h_cnt <= 0;
            if (r_v_cnt < V_TOTAL - 1) begin
                r_v_cnt <= r_v_cnt + 1;
            end else begin
                r_v_cnt <= 0;
            end
        end
    end

    // Sync Signals (Active Low)
    always @(posedge clk25) begin
        vga_hsync <= (r_h_cnt >= (H_ACTIVE + H_FRONT) && r_h_cnt < (H_ACTIVE + H_FRONT + H_SYNC)) ? 1'b0 : 1'b1;
        vga_vsync <= (r_v_cnt >= (V_ACTIVE + V_FRONT) && r_v_cnt < (V_ACTIVE + V_FRONT + V_SYNC)) ? 1'b0 : 1'b1;
    end

    assign active_video = (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE);
    assign next_h_cnt = (r_h_cnt == H_TOTAL - 1) ? 10'b0 : r_h_cnt + 1;
    assign next_v_cnt = (r_h_cnt == H_TOTAL - 1) ? ((r_v_cnt == V_TOTAL - 1) ? 10'b0 : r_v_cnt + 1) : r_v_cnt;
    assign next_active_video = (next_h_cnt < H_ACTIVE && next_v_cnt < V_ACTIVE);
    assign next_frame_addr = next_active_video ? (next_v_cnt[9:1] * 320) + next_h_cnt[9:1] : 17'b0;

    // Pixel Doubling & Address Generation (320x240 memory -> 640x480 screen)
    always @(posedge clk25) begin
        frame_addr     <= next_frame_addr;
        r_frame_pixel  <= frame_pixel;
        r_active_video <= next_active_video;
    end

    // Output and Filter Selection
    always @(posedge clk25) begin
        if (r_active_video) begin
            case (filter_sw)
                2'b00: begin // RAW FEED
                    vga_red   <= r_in;
                    vga_green <= g_in;
                    vga_blue  <= b_in;
                end
                2'b01: begin // FILTER 1: Grayscale
                    vga_red   <= gray;
                    vga_green <= gray;
                    vga_blue  <= gray;
                end
                2'b10: begin // FILTER 2: Binary Threshold
                    vga_red   <= thresh;
                    vga_green <= thresh;
                    vga_blue  <= thresh;
                end
                2'b11: begin // FILTER 3: Red Isolation
                    vga_red   <= r_in;
                    vga_green <= 4'b0;
                    vga_blue  <= 4'b0;
                end
            endcase
        end else begin
            vga_red   <= 4'h0;
            vga_green <= 4'h0;
            vga_blue  <= 4'h0;
        end
    end

endmodule