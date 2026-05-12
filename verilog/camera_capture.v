module camera_capture #(
    parameter integer FRAME_WIDTH  = 320,
    parameter integer FRAME_HEIGHT = 240,
    parameter integer CROP_LEFT    = 4,
    parameter integer CROP_TOP     = 2
) (
    input             pclk,
    input             vsync,
    input             href,
    input      [ 7:0] d,
    output reg [16:0] addr,
    output reg [11:0] dout,
    output reg        we
);
    reg       byte_half;
    reg       href_prev;
    reg [7:0] byte1_latch;
    reg [9:0] src_x;
    reg [9:0] src_y;

    wire [9:0] dst_x = src_x - CROP_LEFT;
    wire [9:0] dst_y = src_y - CROP_TOP;
    wire       in_capture_window =
        (src_x >= CROP_LEFT) &&
        (src_y >= CROP_TOP) &&
        (dst_x < FRAME_WIDTH) &&
        (dst_y < FRAME_HEIGHT);
    wire [16:0] next_addr = (dst_y * FRAME_WIDTH) + dst_x;

    initial begin
        addr = 17'b0;
        dout = 12'b0;
        we = 1'b0;
        byte_half = 1'b0;
        href_prev = 1'b0;
        byte1_latch = 8'b0;
        src_x = 10'b0;
        src_y = 10'b0;
    end

    always @(negedge pclk) begin
        we <= 1'b0;
        href_prev <= href;

        if (vsync == 1'b1) begin
            addr      <= 17'b0;
            byte_half <= 1'b0;
            href_prev <= 1'b0;
            src_x     <= 10'b0;
            src_y     <= 10'b0;
        end else if (href == 1'b1) begin
            if (byte_half == 1'b0) begin
                byte1_latch <= d;
                byte_half   <= 1'b1;
            end else begin
                if (in_capture_window) begin
                    addr <= next_addr;
                    dout <= {byte1_latch[7:4], byte1_latch[2:0], d[7], d[4:1]};
                    we   <= 1'b1;
                end
                src_x     <= src_x + 10'd1;
                byte_half <= 1'b0;
            end
        end else begin
            byte_half <= 1'b0;
            src_x     <= 10'b0;
            if (href_prev == 1'b1) begin
                src_y <= src_y + 10'd1;
            end
        end
    end
endmodule
