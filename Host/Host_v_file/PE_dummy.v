module processing_element (
    input wire          clk,
    input wire          rst,
    input wire  [31:0]  operand_A,
    input wire  [31:0]  operand_B,
    input wire          valid_in,
    input wire          chp_slct,
    input wire  [2:0]   op_code,
    output reg          busy,
    output reg          valid_out,
    output reg  [7:0]   data_out
);

    reg [31:0] reg_A;
    reg [31:0] reg_B;
    wire [31:0] dummy_sum;

    // Direct Testing: Check for Chip Select and Valid In gating 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_A <= 32'h0;
            reg_B <= 32'h0;
            busy  <= 1'b0;
        end else begin
            // Operands are sampled ONLY when both chp_slct and valid_in are active 
            if (chp_slct && valid_in) begin
                reg_A <= operand_A;
                reg_B <= operand_B;
                busy  <= 1'b1; // Mimic entering a processing state 
            end else begin
                busy  <= 1'b0;
            end
        end
    end

    // Simple Dummy Math: Add them together
    assign dummy_sum = reg_A + reg_B;

    // Match your spec: Output synchronization latch
    // Since we are returning 8 bits over UART, we'll take the lowest byte of the sum
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= 8'h0;
        end else if (busy) begin
            valid_out <= 1'b1; // Assert valid_out when result is ready 
            data_out  <= dummy_sum[7:0]; // Snip the lowest 8 bits for easy viewing
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule