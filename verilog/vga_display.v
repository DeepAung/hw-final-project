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
    localparam V_BACK   = 29;
    localparam V_TOTAL  = 525;

    reg [9:0] r_h_cnt = 0;
    reg [9:0] r_v_cnt = 0;

    // Counters: track the current X and Y positions.
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

    // ----------------------------------------------------
    // PIPELINE STAGE 1: generate the BRAM address and temporary sync signals.
    // ----------------------------------------------------
    reg p1_hsync, p1_vsync, p1_active;
    always @(posedge clk25) begin
        p1_hsync  <= (r_h_cnt >= (H_ACTIVE + H_FRONT) && r_h_cnt < (H_ACTIVE + H_FRONT + H_SYNC)) ? 1'b0 : 1'b1;
        p1_vsync  <= (r_v_cnt >= (V_ACTIVE + V_FRONT) && r_v_cnt < (V_ACTIVE + V_FRONT + V_SYNC)) ? 1'b0 : 1'b1;
        p1_active <= (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE);
        
        // Send the address to fetch data from BRAM using pixel doubling.
        if (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE) begin
            frame_addr <= (r_v_cnt[9:1] * 320) + r_h_cnt[9:1];
        end else begin
            frame_addr <= 17'b0;
        end
    end

    // ----------------------------------------------------
    // PIPELINE STAGE 2: wait for BRAM to fetch data, adding latency delay.
    // ----------------------------------------------------
    // BRAM fetches data during this clock, so delay sync by one clock to match.
    reg p2_hsync, p2_vsync, p2_active;
    always @(posedge clk25) begin
        p2_hsync  <= p1_hsync;
        p2_vsync  <= p1_vsync;
        p2_active <= p1_active;
    end

    wire [11:0] filtered_pixel;
    image_filter image_filter_inst (
        .filter_sw(filter_sw),
        .pixel_in  (frame_pixel),
        .pixel_out (filtered_pixel)
    );

    // ----------------------------------------------------
    // PIPELINE STAGE 3: data is ready; drive the display outputs.
    // ----------------------------------------------------
    // Sync and pixel data arrive at this point aligned.
    always @(posedge clk25) begin
        vga_hsync <= p2_hsync;
        vga_vsync <= p2_vsync;
        
        if (p2_active) begin
            vga_red   <= filtered_pixel[11:8];
            vga_green <= filtered_pixel[7:4];
            vga_blue  <= filtered_pixel[3:0];
        end else begin
            vga_red   <= 4'h0;
            vga_green <= 4'h0;
            vga_blue  <= 4'h0;
        end
    end

endmodule
