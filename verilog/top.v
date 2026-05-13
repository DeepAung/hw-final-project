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

    // -----------------------------------------------------------------------
    // Hardware Clocking Wizard (MMCM)
    // -----------------------------------------------------------------------
    wire clk_25MHz;
    wire locked;
    
    clk_wiz_0 u_clk_wiz (
        .clk_in1  (clk_100MHz),
        .reset    (reset),
        .clk_out1 (clk_25MHz),
        .locked   (locked)
    );

    // System Reset: Active high when button is pressed OR clocks are unstable
    wire sys_reset = reset | ~locked;
    
    // -----------------------------------------------------------------------
    // Internal Signals
    // -----------------------------------------------------------------------
    wire [16:0] capture_addr;
    wire [11:0] capture_data;
    wire        capture_we;  
    wire        capture_frame_done;

    wire [16:0] display_addr;
    wire [11:0] frame_pixel; 

    // Camera Configuration Hardware Pins
    assign OV7670_PWDN = 1'b0; 
    assign OV7670_RST  = 1'b1; 
    assign OV7670_XCLK = clk_25MHz; 

    // -----------------------------------------------------------------------
    // Sub-Modules
    // -----------------------------------------------------------------------
    camera_capture capture (
        .pclk      (OV7670_PCLK),
        .vsync     (OV7670_VSYNC),
        .href      (OV7670_HREF),
        .d         (OV7670_D),
        .addr      (capture_addr),
        .dout      (capture_data),
        .we        (capture_we),
        .frame_done(capture_frame_done)
    );

    // Clock Domain Crossing (CDC) for frame_done
    reg capture_frame_done_toggle = 1'b0;
    always @(posedge OV7670_PCLK) begin
        if (capture_frame_done) begin
            capture_frame_done_toggle <= ~capture_frame_done_toggle;
        end
    end

    // The ASYNC_REG tag ensures Vivado places these flip-flops together physically
    (* ASYNC_REG = "TRUE" *) reg [2:0] frame_done_sync = 3'b0;
    always @(posedge clk_25MHz) begin
        frame_done_sync <= {frame_done_sync[1:0], capture_frame_done_toggle};
    end

    reg frame_valid = 1'b0;
    always @(posedge clk_25MHz) begin
        if (sys_reset) begin
            frame_valid <= 1'b0;
        end else if (frame_done_sync[2] ^ frame_done_sync[1]) begin
            frame_valid <= 1'b1;
        end
    end

    blk_mem_gen_0 u_frame_buffer (
        .clka  (OV7670_PCLK),
        .wea   (capture_we),
        .addra (capture_addr),
        .dina  (capture_data),
        .clkb  (clk_25MHz),
        .addrb (display_addr),
        .doutb (frame_pixel)
    );

    I2C_AV_Config IIC (
        .iCLK       (clk_25MHz),
        .iRST_N     (~sys_reset), // Active Low Reset
        .Config_Done(),
        .I2C_SDAT   (OV7670_SDAT),
        .I2C_SCLK   (OV7670_SCLK),
        .LUT_INDEX  (),
        .I2C_RDATA  ()
    );
    
    wire hsync_raw;
    wire vsync_raw;

    vga_display vga_display (
        .clk25      (clk_25MHz),
        .frame_valid(frame_valid),
        .filter_sw  (sw),                
        .vga_red    (vga_rgb[11:8]),
        .vga_green  (vga_rgb[7:4]),
        .vga_blue   (vga_rgb[3:0]),
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
    
    assign vga_hsync = hsync_delay[1]; 
    assign vga_vsync = vsync_delay[1];

endmodule 