// from https://nandland.com/uart-serial-port-module/

module UART(
	input clk,
    input rst,
	input iRx_serial, // the serial input
    output Rx_valid, // the recieved byte is valid
    output [7:0] rx_data,
    input iTx_DV, // data to transmit is valid. start transmitting
    input [7:0] i_Tx_Byte,
    output o_Tx_Active,
    output o_Tx_Serial,
    output o_Tx_Done
);

// this is the final version
uart_rx uart_r(clk,iRx_serial,Rx_valid,rx_data); 
// for testingonly, looping back the tx into rx
//uart_rx uart_r(MAX10_CLK1_50,o_Tx_Serial,Rx_valid,rx_data);

uart_tx uart_t(clk,iTx_DV,i_Tx_Byte,o_Tx_Active,o_Tx_Serial,o_Tx_Done);


endmodule