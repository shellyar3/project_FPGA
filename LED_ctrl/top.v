module top(
    input  wire CLOCK_50,
    input  wire KEY0,      // chosen push button
    output wire LED0,	   // LED0 for output 
    output wire LED1	   // LED1 for output
);

    wire btn = ~KEY0;      // for the FPGA inverting to active high

    led_ctrl U1 (
        .clk (CLOCK_50),   // clock input
        .push_button(btn), // active high button
        .led_on_0 (LED0),  // LED0 output
        .led_on_1 (LED1)   // LED1 output
    );

endmodule
