`timescale 1ns / 1ps

module top (
    input clk_100MHz,
    input reset,
    input [1:0] sw,           // 2 slide switches for filter selection

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
        .reset     (reset),
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
    wire        capture_frame_done;

    wire [16:0] display_addr;
    wire [11:0] frame_pixel; // Data read from RAM

    // Camera Configuration Hardware Pins
    assign OV7670_PWDN = 1'b0; // Power down: Normal mode
    assign OV7670_RST  = 1'b1; // Reset: Active low, so keep high
    assign OV7670_XCLK = clk_25MHz; // Camera needs a system clock

    camera_capture capture (
        .pclk (OV7670_PCLK),
        .vsync(OV7670_VSYNC),
        .href (OV7670_HREF),
        .d    (OV7670_D),
        .addr (capture_addr),
        .dout (capture_data),
        .we   (capture_we),
        .frame_done(capture_frame_done)
    );

    // Clock Domain Crossing (CDC) for frame_done
    reg capture_frame_done_toggle = 1'b0;
    always @(posedge OV7670_PCLK) begin
        if (capture_frame_done) begin
            capture_frame_done_toggle <= ~capture_frame_done_toggle;
        end
    end

    reg [2:0] frame_done_sync = 3'b0;
    always @(posedge clk_25MHz) begin
        frame_done_sync <= {frame_done_sync[1:0], capture_frame_done_toggle};
    end

    reg frame_valid = 1'b0;
    always @(posedge clk_25MHz) begin
        if (reset_debounced) begin
            frame_valid <= 1'b0;
        end else if (frame_done_sync[2] ^ frame_done_sync[1]) begin
            frame_valid <= 1'b1;
        end
    end

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
    
    // Internal wires to hold the un-delayed sync signals
    wire hsync_raw;
    wire vsync_raw;

    vga_display vga_display (
        .clk25      (clk_25MHz),
        .frame_valid(frame_valid),
        .filter_sw  (sw),                
        .vga_red    (vga_rgb[11:8]),
        .vga_green  (vga_rgb[7:4]),
        .vga_blue   (vga_rgb[3:0]),
        
        // Output to internal raw wires instead of directly to top module ports
        .vga_hsync  (hsync_raw),
        .vga_vsync  (vsync_raw),

        .frame_addr (display_addr),    
        .frame_pixel(frame_pixel)
    );

    // -----------------------------------------------------------------------
    // LEFT BAR FIX: VGA Sync Delay Compensation
    // Delays the sync signals by 2 clock cycles to align with BRAM latency
    // -----------------------------------------------------------------------
    reg [1:0] hsync_delay;
    reg [1:0] vsync_delay;
    
    always @(posedge clk_25MHz) begin
        hsync_delay <= {hsync_delay[0], hsync_raw};
        vsync_delay <= {vsync_delay[0], vsync_raw};
    end
    
    // Assign the delayed signals to the actual VGA output pins
    assign vga_hsync = hsync_delay[1]; 
    assign vga_vsync = vsync_delay[1];

endmodule