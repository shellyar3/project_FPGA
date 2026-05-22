`timescale 1ns / 1ps

module MAC_and_SCALE (
    input wire clk,
    input wire rst,
    input wire [31:0] port_A,
    input wire [31:0] port_B,
    output reg [63:0] accumulator,

    input wire mode4x4,
    input wire a_is_signed,
    input wire b_is_signed,
    input wire scale_mode,
    input wire [1:0] scale_phase,
    input wire mac4_en,
    input wire mac8_en,
    input wire [1:0] acc_source,
    input wire acc_wr_en,
    input wire acc_load,
    input wire rst_acc
);

    // Input Routing

    reg [23:0] holding_reg;

    always @(posedge clk or negedge rst) begin
        if (!rst)
            holding_reg <= 24'b0;
        else if (acc_load)
            holding_reg <= accumulator[31:8];
    end

    // Broadcast Byte Selection

    reg [7:0] broadcast_byte;
    always @(*) begin
        case (scale_phase)
            2'b00: broadcast_byte = accumulator[7:0];
            2'b01: broadcast_byte = holding_reg[7:0];
            2'b10: broadcast_byte = holding_reg[15:8];
            2'b11: broadcast_byte = holding_reg[23:16];
        endcase
    end

    // A_Byte(s): Source Mux and Broadcast/Split

    wire [7:0] byteA0 = scale_mode ? broadcast_byte : port_A[7:0];
    wire [7:0] byteA1 = scale_mode ? broadcast_byte : port_A[15:8];
    wire [7:0] byteA2 = scale_mode ? broadcast_byte : port_A[23:16];
    wire [7:0] byteA3 = scale_mode ? broadcast_byte : port_A[31:24];

    // B_Bytes: Always split

    wire [7:0] byteB0 = port_B[7:0];
    wire [7:0] byteB1 = port_B[15:8];
    wire [7:0] byteB2 = port_B[23:16];
    wire [7:0] byteB3 = port_B[31:24];

    // Compute Core

    // Multiplier Array

    wire signed [15:0] mult_8_0, mult_8_1, mult_8_2, mult_8_3;
    wire signed [7:0] mult_4_0_bottom, mult_4_0_top;
    wire signed [7:0] mult_4_1_bottom, mult_4_1_top;
    wire signed [7:0] mult_4_2_bottom, mult_4_2_top;
    wire signed [7:0] mult_4_3_bottom, mult_4_3_top;

    MP_Multiplier mult_0 (
        .a(byteA0), .b(byteB0), .mode4x4(mode4x4),
        .a_signed(a_is_signed), .b_signed(b_is_signed),
        .mult8out(mult_8_0),
        .bottom_mult4out(mult_4_0_bottom), .top_mult4out(mult_4_0_top)
    );

    MP_Multiplier mult_1 (
        .a(byteA1), .b(byteB1), .mode4x4(mode4x4),
        .a_signed(a_is_signed), .b_signed(b_is_signed),
        .mult8out(mult_8_1),
        .bottom_mult4out(mult_4_1_bottom), .top_mult4out(mult_4_1_top)
    );

    MP_Multiplier mult_2 (
        .a(byteA2), .b(byteB2), .mode4x4(mode4x4),
        .a_signed(a_is_signed), .b_signed(b_is_signed),
        .mult8out(mult_8_2),
        .bottom_mult4out(mult_4_2_bottom), .top_mult4out(mult_4_2_top)
    );

    MP_Multiplier mult_3 (
        .a(byteA3), .b(byteB3), .mode4x4(mode4x4),
        .a_signed(a_is_signed), .b_signed(b_is_signed),
        .mult8out(mult_8_3),
        .bottom_mult4out(mult_4_3_bottom), .top_mult4out(mult_4_3_top)
    );

    // MAC4 Reduction Tree (3 stages)
    // Inputs forced to zero when mac4_en is low (operand isolation).

    wire signed [7:0] mac4_in_0 = mac4_en ? mult_4_0_bottom : 8'sd0;
    wire signed [7:0] mac4_in_1 = mac4_en ? mult_4_0_top    : 8'sd0;
    wire signed [7:0] mac4_in_2 = mac4_en ? mult_4_1_bottom : 8'sd0;
    wire signed [7:0] mac4_in_3 = mac4_en ? mult_4_1_top    : 8'sd0;
    wire signed [7:0] mac4_in_4 = mac4_en ? mult_4_2_bottom : 8'sd0;
    wire signed [7:0] mac4_in_5 = mac4_en ? mult_4_2_top    : 8'sd0;
    wire signed [7:0] mac4_in_6 = mac4_en ? mult_4_3_bottom : 8'sd0;
    wire signed [7:0] mac4_in_7 = mac4_en ? mult_4_3_top    : 8'sd0;

    // Stage 1: four 8-bit signed adders -> four 9-bit signed sums
    wire signed [8:0] mac4_s1_0 = mac4_in_0 + mac4_in_1;
    wire signed [8:0] mac4_s1_1 = mac4_in_2 + mac4_in_3;
    wire signed [8:0] mac4_s1_2 = mac4_in_4 + mac4_in_5;
    wire signed [8:0] mac4_s1_3 = mac4_in_6 + mac4_in_7;

    // Stage 2: two 9-bit signed adders -> two 10-bit signed sums
    wire signed [9:0] mac4_s2_0 = mac4_s1_0 + mac4_s1_1;
    wire signed [9:0] mac4_s2_1 = mac4_s1_2 + mac4_s1_3;

    // Stage 3: one 10-bit signed adder -> 11-bit signed result
    wire signed [10:0] mac4_result = mac4_s2_0 + mac4_s2_1;

    // MAC8 Reduction Tree (2 stages)
    // Inputs forced to zero when mac8_en is low (operand isolation).

    wire signed [15:0] mac8_in_0 = mac8_en ? mult_8_0 : 16'sd0;
    wire signed [15:0] mac8_in_1 = mac8_en ? mult_8_1 : 16'sd0;
    wire signed [15:0] mac8_in_2 = mac8_en ? mult_8_2 : 16'sd0;
    wire signed [15:0] mac8_in_3 = mac8_en ? mult_8_3 : 16'sd0;

    // Stage 1: two 16-bit signed adders -> two 17-bit signed sums
    wire signed [16:0] mac8_s1_0 = mac8_in_0 + mac8_in_1;
    wire signed [16:0] mac8_s1_1 = mac8_in_2 + mac8_in_3;

    // Stage 2: one 17-bit signed adder -> 18-bit signed result
    wire signed [17:0] mac8_result = mac8_s1_0 + mac8_s1_1;

    // SCALE Stitching Tree

    wire [15:0] scale_iso_0 = scale_mode ? mult_8_0 : 16'b0;
    wire [15:0] scale_iso_1 = scale_mode ? mult_8_1 : 16'b0;
    wire [15:0] scale_iso_2 = scale_mode ? mult_8_2 : 16'b0;
    wire [15:0] scale_iso_3 = scale_mode ? mult_8_3 : 16'b0;

    wire [23:0] stitch_ext_0 = a_is_signed ? {{8{scale_iso_0[15]}}, scale_iso_0} : {8'b0, scale_iso_0};
    wire [23:0] stitch_ext_2 = a_is_signed ? {{8{scale_iso_2[15]}}, scale_iso_2} : {8'b0, scale_iso_2};

    wire [23:0] stitch_s1_lo = stitch_ext_0 + {scale_iso_1, 8'b0};
    wire [23:0] stitch_s1_hi = stitch_ext_2 + {scale_iso_3, 8'b0};

    wire [39:0] stitch_lo_ext = a_is_signed ? {{16{stitch_s1_lo[23]}}, stitch_s1_lo} : {16'b0, stitch_s1_lo};
    wire [39:0] stitch_40 = stitch_lo_ext + {stitch_s1_hi, 16'b0};

    // Alignment & Select Unit

    wire [31:0] mac4_addend = {{21{mac4_result[10]}}, mac4_result};
    wire [31:0] mac8_addend = {{14{mac8_result[17]}}, mac8_result};

    reg [63:0] scale_addend;
    always @(*) begin
        case (scale_phase)
            2'b00: scale_addend = {24'b0, stitch_40};
            2'b01: scale_addend = {16'b0, stitch_40, 8'b0};
            2'b10: scale_addend = {8'b0, stitch_40, 16'b0};
            2'b11: scale_addend = {stitch_40, 24'b0};
        endcase
    end

    reg [31:0] addend_lo;
    always @(*) begin
        case (acc_source)
            2'b00: addend_lo = mac4_addend;
            2'b01: addend_lo = mac8_addend;
            2'b10: addend_lo = scale_addend[31:0];
            2'b11: addend_lo = port_B;
        endcase
    end

    wire [31:0] addend_hi = scale_addend[63:32];

    // Accumulation Unit

    wire [31:0] gated_lo_feedback = accumulator[31:0] & {32{~acc_load}};
    wire upper_fb_gate = scale_mode & ~acc_load;
    wire [31:0] gated_hi_feedback = accumulator[63:32] & {32{upper_fb_gate}};
    wire [31:0] gated_hi_addend = addend_hi & {32{scale_mode}};

    wire [32:0] lower_sum = {1'b0, addend_lo} + {1'b0, gated_lo_feedback};
    wire lower_cout = lower_sum[32];
    wire [31:0] lower_result = lower_sum[31:0];

    wire gated_carry = lower_cout & scale_mode;
    wire [31:0] upper_result = gated_hi_addend + gated_hi_feedback + {31'b0, gated_carry};

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            accumulator <= 64'b0;
        end
        else if (rst_acc) begin
            accumulator <= 64'b0;
        end
        else if (acc_wr_en) begin
            accumulator[31:0] <= lower_result;
            if (scale_mode)
                accumulator[63:32] <= upper_result;
            else
            accumulator[63:32] <= {32{lower_result[31]}};
        end
    end

endmodule