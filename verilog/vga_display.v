`timescale 1ns / 1ps

// VGA display controller — 640x480 @ 60 Hz with pixel-doubling for 320x240 frame buffer.
// Filter selection is combinational via image_filter module; output is registered.
//
// filter_sw:  00=raw  01=grayscale  10=inversion  11=red-only
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

    // VGA 640x480 @ 60 Hz timing constants (25 MHz pixel clock)
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

    // Horizontal and vertical counters
    always @(posedge clk25) begin
        if (r_h_cnt < H_TOTAL - 1) begin
            r_h_cnt <= r_h_cnt + 1;
        end else begin
            r_h_cnt <= 0;
            if (r_v_cnt < V_TOTAL - 1)
                r_v_cnt <= r_v_cnt + 1;
            else
                r_v_cnt <= 0;
        end
    end

    // Sync signals — active low per VGA standard
    always @(posedge clk25) begin
        vga_hsync <= ~(r_h_cnt >= (H_ACTIVE + H_FRONT) &&
                       r_h_cnt <  (H_ACTIVE + H_FRONT + H_SYNC));
        vga_vsync <= ~(r_v_cnt >= (V_ACTIVE + V_FRONT) &&
                       r_v_cnt <  (V_ACTIVE + V_FRONT + V_SYNC));
    end

    assign active_video = (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE);

    // Frame-buffer address: pixel-double 320x240 → 640x480 by dropping LSB of each axis
    always @(*) begin
        if (active_video)
            frame_addr = ({7'b0, r_v_cnt[9:1]} * 17'd320) + {8'b0, r_h_cnt[9:1]};
        else
            frame_addr = 17'd0;
    end

    // Unpack the 12-bit pixel (RGB444) from the frame buffer
    wire [3:0] r_in = frame_pixel[11:8];
    wire [3:0] g_in = frame_pixel[7:4];
    wire [3:0] b_in = frame_pixel[3:0];

    // Filtered pixel (combinational — zero added latency)
    wire [3:0] r_filt, g_filt, b_filt;
    image_filter filter_inst (
        .filter_sw(filter_sw),
        .r_in     (r_in),
        .g_in     (g_in),
        .b_in     (b_in),
        .r_out    (r_filt),
        .g_out    (g_filt),
        .b_out    (b_filt)
    );

    // Register filtered pixel to VGA outputs; blank outside active region
    always @(posedge clk25) begin
        if (active_video) begin
            vga_red   <= r_filt;
            vga_green <= g_filt;
            vga_blue  <= b_filt;
        end else begin
            vga_red   <= 4'h0;
            vga_green <= 4'h0;
            vga_blue  <= 4'h0;
        end
    end

endmodule
