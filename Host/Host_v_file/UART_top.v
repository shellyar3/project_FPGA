module UART_top (
    input wire          MAX10_CLK1_50, // 50MHz oscillator
    input wire  [1:0]   KEY,           // KEY[0] used as Master System Reset
    output wire [9:0]   LEDR,          // System Diagnostics array
    input wire          iRx_serial,    // Hardwired to PIN_V10
    output wire         o_Tx_Serial,   // Hardwired to PIN_W10
    output wire         clk_1hz        // Global Heartbeat line
);

    wire reset;
    wire Rx_valid, o_Tx_Done, iTx_DV_bridge;
    wire [7:0] rx_data, tx_data_bridge;

    // DUT Interconnect Lines
    wire [31:0] op_A, op_B;
    wire        val_in, chp_slct, busy, val_out;
    wire [2:0]  op_code;
    wire [7:0]  pe_data_out;

    // Pulse monitoring system
    control ctrl_inst (
        .clk(MAX10_CLK1_50),
        .key(KEY),
        .rst(reset),
        .ledr(LEDR),
        .clk_1hz(clk_1hz)
    );

    // UART Communication Core Module
    UART my_uart (
        .clk(MAX10_CLK1_50),
        .rst(reset),
        .iRx_serial(iRx_serial),
        .Rx_valid(Rx_valid),
        .rx_data(rx_data),
        .iTx_DV(iTx_DV_bridge),
        .i_Tx_Byte(tx_data_bridge),
        .o_Tx_Active(),
        .o_Tx_Serial(o_Tx_Serial),
        .o_Tx_Done(o_Tx_Done)
    );

    // Processing Element Translation Module
    pe_uart_bridge bridge_inst (
        .clk(MAX10_CLK1_50),
        .rst(reset),
        .Rx_valid(Rx_valid),
        .rx_data(rx_data),
        .iTx_DV(iTx_DV_bridge),
        .tx_data(tx_data_bridge),
        .o_Tx_Done(o_Tx_Done),
        .DUT_operand_A(op_A),
        .DUT_operand_B(op_B),
        .DUT_valid_in(val_in),
        .DUT_chp_slct(chp_slct),
        .DUT_op_code(op_code),
        .DUT_busy(busy),
        .DUT_valid_out(val_out),
        .DUT_data_out(pe_data_out)
    );

    // Device Under Test (DUT) Instance Boundary
    processing_element DUT (
        .clk(MAX10_CLK1_50),
        .rst(reset),
        .operand_A(op_A),
        .operand_B(op_B),
        .valid_in(val_in),
        .chp_slct(chp_slct),
        .op_code(op_code),
        .busy(busy),
        .valid_out(val_out),
        .data_out(pe_data_out)
    );

endmodule