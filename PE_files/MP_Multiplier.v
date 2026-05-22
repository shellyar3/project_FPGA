module MP_Multiplier(
    input signed [7:0] a,
    input signed [7:0] b,
    input mode4x4,
    input a_signed,
    input b_signed,
    output signed [15:0] mult8out,
    output signed [7:0] bottom_mult4out,
    output signed [7:0] top_mult4out
);

    // Split the 8-bit inputs into 4-bit upper and lower halves
    wire [3:0] a0 = a[3:0];
    wire [3:0] a1 = a[7:4];
    wire [3:0] b0 = b[3:0];
    wire [3:0] b1 = b[7:4];

    // Sign control flags for the top and bottom multipliers based on the mode
    wire mult00_sign = mode4x4;
    wire mult11_sign_a = (mode4x4) ? 1'b1 : a_signed;
    wire mult11_sign_b = (mode4x4) ? 1'b1 : b_signed;

    // Wires to hold the 9-bit outputs from each 4x4 multiplier
    wire [8:0] mult00;
    wire [8:0] mult01;
    wire [8:0] mult10;
    wire [8:0] mult11;

    // Sign bits from the cross terms to be used for sign extension in the final addition
    wire sign_01 = mult01[8];
    wire sign_10 = mult10[8];

    // Operand isolation logic: Gate the inputs to zero during INT4 mode to save dynamic power.
    // When mode4x4 is high, these inputs become 4'b0000, freezing the cross-term multipliers.
    wire [3:0] gated_a0_01 = mode4x4 ? 4'b0000 : a0;
    wire [3:0] gated_b1_01 = mode4x4 ? 4'b0000 : b1;
    
    wire [3:0] gated_a1_10 = mode4x4 ? 4'b0000 : a1;
    wire [3:0] gated_b0_10 = mode4x4 ? 4'b0000 : b0;

    // Instantiate the four 4x4 multipliers
    
    // mult_00: Bottom multiplier. In INT8, both inputs are unsigned. In INT4, they are signed.
    Multiplier4 mult_00 (.a(a0), .b(b0), .a_signed(mult00_sign), .b_signed(mult00_sign), .mult4out(mult00));
    
    // mult_01 & mult_10: Cross terms. Inputs are gated to save power in INT4 mode.
    Multiplier4 mult_01 (.a(gated_a0_01), .b(gated_b1_01), .a_signed(1'b0), .b_signed(b_signed), .mult4out(mult01));
    Multiplier4 mult_10 (.a(gated_a1_10), .b(gated_b0_10), .a_signed(a_signed), .b_signed(1'b0), .mult4out(mult10));
    
    // mult_11: Top multiplier. Always takes the upper halves.
    Multiplier4 mult_11 (.a(a1), .b(b1), .a_signed(mult11_sign_a), .b_signed(mult11_sign_b), .mult4out(mult11));

    // Shift and add the partial products to create the final 16-bit output for INT8 mode.
    // The cross terms are sign-extended to prevent corruption of negative numbers.
    assign mult8out = {8'b0, mult00[7:0]} + 
                      {{4{sign_01}}, mult01[7:0], 4'b0} + 
                      {{4{sign_10}}, mult10[7:0], 4'b0} + 
                      {mult11[7:0], 8'b0};

    // Independent 4-bit outputs to use directly during INT4 mode
    assign bottom_mult4out = mult00[7:0];
    assign top_mult4out = mult11[7:0];

endmodule