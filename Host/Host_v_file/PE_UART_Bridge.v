module pe_uart_bridge (
    input  wire        clk,
    input  wire        rst,
    input  wire        Rx_valid,
    input  wire [7:0]  rx_data,
    output reg         iTx_DV,
    output reg  [7:0]  tx_data,
    input  wire        o_Tx_Done,
    output reg  [31:0] DUT_operand_A,
    output reg  [31:0] DUT_operand_B,
    output reg         DUT_valid_in, 
    output reg         DUT_chp_slct,
    output reg  [4:0]  DUT_op_code,
    input  wire        DUT_busy,      
    input  wire        DUT_valid_out, 
    input  wire [7:0]  DUT_data_out   
);
    // DECLARATIONS: Ensure all registers used in the block are defined here
    reg [3:0] byte_count;
    reg [2:0] state;
    reg [3:0] wait_counter; // This was the missing declaration!

    localparam S_RX_GATHER=0, S_TRIGGER_PE=1, S_WAIT_PE=2, S_TX_WAIT=3;

    always @(posedge clk) begin
        if (!rst) begin
            state <= S_RX_GATHER; 
            byte_count <= 0;
            wait_counter <= 0;
            DUT_valid_in <= 0; 
            DUT_chp_slct <= 0;
            iTx_DV <= 0;
        end else begin
            case (state)
                S_RX_GATHER: begin
                    iTx_DV <= 0;
                    if (Rx_valid) begin
                        if      (byte_count == 0) DUT_op_code <= rx_data[4:0];
                        else if (byte_count == 1) DUT_operand_A[31:24] <= rx_data;
                        else if (byte_count == 2) DUT_operand_A[23:16] <= rx_data;
                        else if (byte_count == 3) DUT_operand_A[15:8]  <= rx_data;
                        else if (byte_count == 4) DUT_operand_A[7:0]   <= rx_data;
                        else if (byte_count == 5) DUT_operand_B[31:24] <= rx_data;
                        else if (byte_count == 6) DUT_operand_B[23:16] <= rx_data;
                        else if (byte_count == 7) DUT_operand_B[15:8]  <= rx_data;
                        else if (byte_count == 8) DUT_operand_B[7:0]   <= rx_data;
                        
                        if (byte_count == 8) begin 
                            byte_count <= 0; 
                            state <= S_TRIGGER_PE; 
                        end else begin 
                            byte_count <= byte_count + 1; 
                        end
                    end
                end
                
                S_TRIGGER_PE: begin
                    DUT_valid_in <= 1; 
                    DUT_chp_slct <= 1; 
                    state <= S_WAIT_PE;
                end
                
                S_WAIT_PE: begin
                    DUT_valid_in <= 0; 
                    DUT_chp_slct <= 0;
                    // Diagnostic Bypass: Force output if Opcode 6 is received
                    if (DUT_valid_out || (DUT_op_code == 6)) begin
                        tx_data <= DUT_data_out; 
                        iTx_DV  <= 1; 
                        state   <= S_TX_WAIT;
                    end else if (wait_counter == 4'd4) begin
                        state <= S_RX_GATHER;
                        wait_counter <= 0;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
                
                S_TX_WAIT: begin
                    iTx_DV <= 0; 
                    if (o_Tx_Done) state <= S_RX_GATHER;
                end
            endcase
        end
    end
endmodule