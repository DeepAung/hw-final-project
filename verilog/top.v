`timescale 1ns / 1ps

// FOR USE WITH AN FPGA THAT HAS 12 PINS FOR RGB VALUES, 4 PER COLOR


module top (
    input         clk_100MHz,
    input         reset,
    input  [11:0] sw,
    input  [ 7:0] JB,
    input  [ 7:0] JC,
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

    ov7670_capture capture (
        .pclk (OV7670_PCLK),
        .vsync(OV7670_VSYNC),
        .href (OV7670_HREF),
        .d    (OV7670_D),
        .addr (capture_addr),
        .dout (capture_data),
        .we   (capture_we)
    );

    // frame_buffer your_vram_inst (
    //     .clka (OV7670_PCLK),
    //     .wea  (capture_we),
    //     .addra(capture_addr),
    //     .dina (capture_data),
    //     .clkb (clk_25MHz),
    //     .addrb(display_addr),
    //     .doutb(frame_pixel)
    // );

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

    // Instantiate VGA Controller
    vga_controller vga_c (
        .clk_100MHz(clk_100MHz),
        .clk_25MHz (clk_25MHz),
        .reset     (reset_debounced),
        .hsync     (vga_hsync),
        .vsync     (vga_vsync),
        .video_on  (video_on),
        .p_tick    (),
        .x         (vga_x),
        .y         (vga_y)
    );

    // // RGB Buffer
    // always @(posedge clk_100MHz or posedge reset_debounced)
    //     if (reset_debounced) rgb_reg <= 0;
    //     else rgb_reg <= sw;

    // Address Mapping Logic
    // If using 320x240 resolution on a 640x480 VGA screen:
    // We divide x and y by 2 (shift right) to scale the image.
    assign display_addr = (vga_y[9:1] * 320) + vga_x[9:1];

    // Final Output
    // If video_on is true, show the pixel from RAM, otherwise black
    assign vga_rgb      = (video_on) ? frame_pixel : 12'b0;

    // // Output
    // assign vga_rgb = (video_on) ? rgb_reg : 12'b0;   // while in display area RGB color = sw, else all OFF

    // // --- Probing --- //
    // ila_data_out ila_inst (
    //     .clk   (clk),
    //     .probe0(capture_addr),
    //     .probe1(data_12)
    // );

endmodule
