module led_ctrl(
    input  wire clk,             // 50MHz clock
    input  wire push_button,     // button input
    output reg  led_on_0 = 0,    // blink
    output reg  led_on_1 = 0     // toggle
);

    // Clock divider for blinking mode
    reg [24:0] counter = 0; // counter for timing

    always @(posedge clk) begin 
        counter <= counter + 1;

        if (counter == 25_000_000) begin   // counter reacher the max then it restarts the counting
            led_on_0 <= ~led_on_0; //flip the state of LED0
            counter <= 0;    //restart counter
        end
    end

    // button toggle section
    reg prev_button = 0; //storing the pevious button value
    always @(posedge clk) begin
        if (push_button && !prev_button) //rising edge detection
            led_on_1 <= ~led_on_1;

        prev_button <= push_button; //storing previous state
    end

endmodule
