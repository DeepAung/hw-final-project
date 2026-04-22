`timescale 1ns / 1ps


module top (
    input clk_100MHz,
    input reset,

    output        vga_hsync,
    output        vga_vsync,
    output [11:0] vga_rgb,

    input  [7:0] OV7670_D,
    input        OV7670_HREF,
    input        OV7670_PCLK,
    output       OV7670_PWDN,
    output       OV7670_RST,
    output       OV7670_SCLK,
    inout        OV7670_SDAT,
    input        OV7670_VSYNC,
    output       OV7670_XCLK
);

    // Clock generator
    wire clk_50MHz;
    wire clk_25MHz;
    clock_gen clock_gen_inst (
        .clk_100MHz(clk_100MHz),
        .clk_50MHz (clk_50MHz),
        .clk_25MHz (clk_25MHz)
    );

    // Reset btn debouncer
    wire reset_debounced;
    debounce debounce_inst (
        .clk(clk_50MHz),
        .i  (reset),
        .o  (reset_debounced)
    );

    // ---------------------- //

    // Internal Signals
    wire [16:0] capture_addr;
    wire [11:0] capture_data;
    wire        capture_we;  // Write Enable from camera

    wire [16:0] display_addr;
    wire [11:0] frame_pixel;  // Data read from RAM
    wire [9:0] vga_x, vga_y;  // Current pixel coordinates

    // Camera Configuration Hardware Pins
    assign OV7670_PWDN = 1'b0;  // Power down: Normal mode
    assign OV7670_RST  = 1'b1;  // Reset: Active low, so keep high
    assign OV7670_XCLK = clk_25MHz;  // Camera needs a system clock

    camera_capture capture (
        .pclk (OV7670_PCLK),
        .vsync(OV7670_VSYNC),
        .href (OV7670_HREF),
        .d    (OV7670_D),
        .addr (capture_addr),
        .dout (capture_data),
        .we   (capture_we)
    );

    blk_mem_gen_0 u_frame_buffer (
        .clka (OV7670_PCLK),
        .wea  (capture_we),
        .addra(capture_addr),
        .dina (capture_data),
        .clkb (clk_25MHz),
        .addrb(display_addr),
        .doutb(frame_pixel)
    );

    I2C_AV_Config IIC (
        .iCLK       (clk_25MHz),
        .iRST_N     (!reset_debounced),
        .Config_Done(),
        .I2C_SDAT   (OV7670_SDAT),
        .I2C_SCLK   (OV7670_SCLK),
        .LUT_INDEX  (),
        .I2C_RDATA  ()
    );

    // ---------------------- //

    // Signal Declaration
    reg  [11:0] rgb_reg;  // Registar for displaying color on a screen
    wire        video_on;  // Same signal as in controller

    vga_display vga_display (
        .clk25    (clk_25MHz),
        .vga_red  (vga_rgb[11:8]),
        .vga_green(vga_rgb[7:4]),
        .vga_blue (vga_rgb[3:0]),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .HCnt     (),
        .VCnt     (),

        .frame_addr (frame_addr),
        .frame_pixel(frame_pixel)
    );

endmodule
