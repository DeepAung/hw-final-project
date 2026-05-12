module clock_gen (
    input  clk_100MHz,
    input  reset,
    output clk_50MHz,
    output clk_25MHz
);
    reg [1:0] counter = 2'b0;

    always @(posedge clk_100MHz) begin
        if (reset) counter <= 0;
        else counter <= counter + 1;
    end

    assign clk_50MHz = counter[0];
    assign clk_25MHz = counter[1];

endmodule
