`timescale 1ns / 1ps

module camera_capture (
    input             pclk,
    input             vsync,
    input             href,
    input      [ 7:0] d,
    output reg [16:0] addr,
    output reg [11:0] dout,
    output reg        we
);

    reg [9:0] x_cnt;
    reg [8:0] y_cnt;
    reg       byte_half;
    reg [7:0] byte1_latch;
    reg       href_prev;

    initial begin
        addr = 0;
        dout = 0;
        we = 0;
        x_cnt = 0;
        y_cnt = 0;
        byte_half = 0;
        byte1_latch = 0;
        href_prev = 0;
    end

    always @(negedge pclk) begin
        we <= 1'b0;
        href_prev <= href;

        // VSYNC: สัญญาณเริ่มเฟรมใหม่ (รีเซ็ตตำแหน่งกลับไปบรรทัดแรก)
        if (vsync == 1'b1) begin
            x_cnt <= 0;
            y_cnt <= 0;
            byte_half <= 0;
        end else begin
            // จับขอบขาลงของ HREF (จบ 1 บรรทัด)
            if (href_prev == 1'b1 && href == 1'b0) begin
                x_cnt <= 0;
                byte_half <= 0;
                if (y_cnt < 240) begin
                    y_cnt <= y_cnt + 1; // เลื่อนลงบรรทัดถัดไป
                end
            end

            // HREF: กล้องกำลังส่งข้อมูลพิกเซลมาให้
            if (href == 1'b1) begin
                if (byte_half == 1'b0) begin
                    byte1_latch <= d; // เก็บ Byte แรกไว้
                    byte_half   <= 1'b1;
                end else begin
                    // กรองรับเฉพาะพิกเซลที่อยู่ในกรอบ 320x240 เท่านั้น
                    if (x_cnt < 320 && y_cnt < 240) begin
                        
                        // คำนวณ Address ใหม่โดยใช้ Shift Bit (เร็วกว่าการคูณ Y * 320)
                        // 320 = 256 + 64 = (y << 8) + (y << 6)
                        addr <= (y_cnt << 8) + (y_cnt << 6) + x_cnt;
                        
                        // ประกอบ RGB565 เป็น 4-bit (12-bit color)
                        dout <= {byte1_latch[7:4], byte1_latch[2:0], d[7], d[4:1]};
                        we   <= 1'b1;
                    end
                    
                    x_cnt <= x_cnt + 1; // ขยับแกน X
                    byte_half <= 1'b0;
                end
            end
        end
    end
endmodule