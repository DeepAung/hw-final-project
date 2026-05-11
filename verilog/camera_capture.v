module camera_capture (
    input             pclk,
    input             vsync,
    input             href,
    input      [ 7:0] d,
    output reg [16:0] addr,
    output reg [11:0] dout,
    output reg        we
);
    reg       byte_half;
    reg [7:0] byte1_latch;

    initial begin
        addr = 17'b0;
        dout = 12'b0;
        we = 1'b0;
        byte_half = 1'b0;
        byte1_latch = 8'b0;
    end

    always @(posedge pclk) begin
        // Default WE to 0 so it pulses for 1 clock cycle
        we <= 1'b0;

        // 1. Handle Memory Addressing
        if (vsync == 1'b1) begin
            addr <= 17'b0;
        end else if (we == 1'b1) begin
            // Increment address after a successful write
            if (addr < 17'd76799) begin
                addr <= addr + 1'b1;
            end
        end

        // 2. Handle Pixel Construction
        if (vsync == 1'b1) begin
            byte_half <= 1'b0;
        end else if (href == 1'b1) begin
            if (byte_half == 1'b0) begin
                // First Byte (Red and Top Green bits)
                byte1_latch <= d;
                byte_half   <= 1'b1;
            end else begin
                // Second Byte (Bottom Green and Blue bits)
                // Maps OV7670 RGB565 to Basys3 12-bit RGB
                dout      <= {byte1_latch[7:4], byte1_latch[2:0], d[7], d[4:1]};
                we        <= 1'b1;
                byte_half <= 1'b0;
            end
        end else begin
            // Reset byte state if href drops unexpectedly between lines
            byte_half <= 1'b0;
        end
    end
endmodule