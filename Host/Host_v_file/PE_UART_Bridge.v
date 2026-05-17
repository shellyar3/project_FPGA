module pe_uart_bridge (
    input wire          clk,
    input wire          rst,
    
    // UART interface
    input wire          Rx_valid,
    input wire  [7:0]   rx_data,
    output reg          iTx_DV,
    output reg  [7:0]   tx_data,
    input wire          o_Tx_Done,
    
    // DUT Hardware Interface Control Strings
    output reg  [31:0]  DUT_operand_A,
    output reg  [31:0]  DUT_operand_B,
    output reg          DUT_valid_in,
    output reg          DUT_chp_slct,
    output reg  [2:0]   DUT_op_code,
    
    // DUT Hardware Feedback Strings
    input wire          DUT_busy,
    input wire          DUT_valid_out,
    input wire  [7:0]   DUT_data_out
);

    // Protocol States
    localparam ST_IDLE       = 3'b000;
    localparam ST_RX_DATA    = 3'b010;
    localparam ST_EXECUTE    = 3'b011;
    localparam ST_TX_RESULT  = 3'b100;

    // State tracking registers
    reg [2:0] state;
    reg [2:0] byte_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= ST_IDLE;
            byte_idx       <= 3'b0;
            iTx_DV         <= 1'b0;
            tx_data        <= 8'h00;
            DUT_operand_A  <= 32'h0;
            DUT_operand_B  <= 32'h0;
            DUT_valid_in   <= 1'b0;
            DUT_chp_slct   <= 1'b0;
            DUT_op_code    <= 3'b0;
        end else begin
            case (state)
                
                ST_IDLE: begin
                    DUT_valid_in <= 1'b0;
                    byte_idx     <= 3'b0;
                    iTx_DV       <= 1'b0; // Ensure transmitter line is ready
                    if (Rx_valid) begin
                        // First Byte defines Control Interface lines
                        // Format: {chp_slct, valid_in, 3'b0, op_code[2:0]}
                        DUT_chp_slct <= rx_data[7];
                        DUT_valid_in <= rx_data[6];
                        DUT_op_code  <= rx_data[2:0];
                        state        <= ST_RX_DATA;
                    end
                end

                ST_RX_DATA: begin
                    if (Rx_valid) begin
                        byte_idx <= byte_idx + 1'b1;
                        // Assemble Big-Endian 32-bit registers sequentially
                        case (byte_idx)
                            3'd0: DUT_operand_A[31:24] <= rx_data;
                            3'd1: DUT_operand_A[23:16] <= rx_data;
                            3'd2: DUT_operand_A[15:8]  <= rx_data;
                            3'd3: DUT_operand_A[7:0]   <= rx_data;
                            3'd4: DUT_operand_B[31:24] <= rx_data;
                            3'd5: DUT_operand_B[23:16] <= rx_data;
                            3'd6: DUT_operand_B[15:8]  <= rx_data;
                            3'd7: begin
                                  DUT_operand_B[7:0]   <= rx_data;
                                  state                <= ST_EXECUTE;
                            end
                        endcase
                    end
                end

                ST_EXECUTE: begin
                    // Wait for the Processing Element logic to finish processing values
                    if (DUT_valid_out) begin
                        state <= ST_TX_RESULT;
                    end else if (!DUT_busy && !DUT_valid_out) begin
                        // Safeguard fallback mechanism if execution finishes instantly
                        state <= ST_TX_RESULT;
                    end
                end

                ST_TX_RESULT: begin
                    if (!iTx_DV) begin
                        iTx_DV  <= 1'b1;
                        // Byte 1: Send status flags {busy, valid_out, 6'b0}
                        tx_data <= {DUT_busy, DUT_valid_out, 6'b0}; 
                    end else if (o_Tx_Done) begin
                        // Check if we just finished sending the status byte
                        if (tx_data != DUT_data_out) begin
                            iTx_DV  <= 1'b1;            // Hold valid high to stream next byte
                            tx_data <= DUT_data_out;    // Load the final calculation calculation byte!
                        end else begin
                            iTx_DV  <= 1'b0;            // Both bytes successfully transmitted
                            state   <= ST_IDLE;         // Return cleanly to wait for next data run
                        end
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule