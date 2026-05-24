// Control is responsible for:
// reset (TBD from top level)
// toggle a led at 1Hz to show this design is a live
// maybe something to do with Key[1] unused input

module control(
    input wire clk,
    input wire [1:0] key,
    output wire rst,          // Changed to wire for clean async routing
    output reg [9:0] ledr,
    output reg clk_1hz        // 1hz clk for testing
);

    // Continuous assignment ensures an instant, reliable system reset
    assign rst = key[0];

    always @(posedge clk) begin
        ledr[7:0] <= 8'b10101010;
        ledr[8]   <= clk_1hz;     // Toggle led at 1Hz
        ledr[9]   <= key[1];     // Toggle led by pressing button
    end

    reg [28:0] counter = 29'd0;
    // 50 Million cycles = 1 Second on a 50MHz oscillator clock
    parameter DIVISOR = 29'd50000000; 

    always @(posedge clk) begin
        counter <= counter + 29'd1;
        if (counter >= (DIVISOR - 1)) begin
            counter <= 29'd0;
        end
        clk_1hz <= (counter < DIVISOR / 2) ? 1'b1 : 1'b0;
    end

endmodule