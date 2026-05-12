module clock_gen (
    input  wire clk_100MHz,
    input  wire reset,
    output wire clk_25MHz,
    output reg  locked
);
`ifdef __ICARUS__
    reg [1:0] counter = 2'b0;

    always @(posedge clk_100MHz) begin
        if (reset) begin
            counter <= 0;
            locked  <= 0;
        end else begin
            counter <= counter + 1;
            locked  <= 1;
        end
    end

    assign clk_25MHz = counter[1];
`else
    clk_wiz_0 clk_wiz (
        .clk_in1 (clk_100MHz),
        .reset   (reset),
        .clk_out1(clk_25MHz),
        .locked  (locked)
    );
`endif
endmodule
