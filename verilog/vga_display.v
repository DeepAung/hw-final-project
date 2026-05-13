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

    // Counters: นับตำแหน่ง X, Y ปกติ
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
    // PIPELINE STAGE 1: สร้าง BRAM Address และ Sync ชั่วคราว
    // ----------------------------------------------------
    reg p1_hsync, p1_vsync, p1_active;
    always @(posedge clk25) begin
        p1_hsync  <= (r_h_cnt >= (H_ACTIVE + H_FRONT) && r_h_cnt < (H_ACTIVE + H_FRONT + H_SYNC)) ? 1'b0 : 1'b1;
        p1_vsync  <= (r_v_cnt >= (V_ACTIVE + V_FRONT) && r_v_cnt < (V_ACTIVE + V_FRONT + V_SYNC)) ? 1'b0 : 1'b1;
        p1_active <= (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE);
        
        // ส่ง Address ไปขอข้อมูลจาก BRAM (Pixel Doubling)
        if (r_h_cnt < H_ACTIVE && r_v_cnt < V_ACTIVE) begin
            frame_addr <= (r_v_cnt[9:1] * 320) + r_h_cnt[9:1];
        end else begin
            frame_addr <= 17'b0;
        end
    end

    // ----------------------------------------------------
    // PIPELINE STAGE 2: รอ BRAM ดึงข้อมูล (Latency Delay)
    // ----------------------------------------------------
    // ใน Clock นี้ BRAM กำลังดึงข้อมูล เราจึงต้องหน่วง Sync ไว้ 1 Clock เพื่อรอ
    reg p2_hsync, p2_vsync, p2_active;
    always @(posedge clk25) begin
        p2_hsync  <= p1_hsync;
        p2_vsync  <= p1_vsync;
        p2_active <= p1_active;
    end

    // เตรียม Filter Logic (เป็น Combinational logic จากข้อมูลที่ได้มาจาก BRAM)
    wire [3:0] r_in = frame_pixel[11:8];
    wire [3:0] g_in = frame_pixel[7:4];
    wire [3:0] b_in = frame_pixel[3:0];
    wire [3:0] gray = (r_in >> 2) + (g_in >> 1) + (b_in >> 2);
    wire [3:0] thresh = (gray > 4'd7) ? 4'hF : 4'h0;

    // ----------------------------------------------------
    // PIPELINE STAGE 3: ข้อมูลพร้อม ส่งออกจอภาพ
    // ----------------------------------------------------
    // Sync และ ข้อมูลภาพ เดินทางมาถึงจุดนี้พร้อมกันพอดีเป๊ะ
    always @(posedge clk25) begin
        vga_hsync <= p2_hsync;
        vga_vsync <= p2_vsync;
        
        if (p2_active) begin
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