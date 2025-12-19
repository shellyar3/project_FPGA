`timescale 1ns/1ps

module tb_led_ctrl();

    reg clk = 0;
    reg push_button = 0;

    wire led_on_0;
    wire led_on_1;

    led_ctrl dut (
        .clk(clk),
        .push_button(push_button),
        .led_on_0(led_on_0),
        .led_on_1(led_on_1)
    );

    always #10 clk = ~clk;  // 50 MHz

    initial begin
        $display("LED testbench starts");
        
        // waiting
        #1000;

        // button press first
        push_button = 1;
        #50;
        push_button = 0;

        // runs the blinker led for sometime
        #100000000; // 100 ms

        // button press second
        push_button = 1;
        #50;
        push_button = 0;

        #100000000;

        $stop;
    end

endmodule
