`timescale 1ns/1ps

module Requantizer (
    input wire clk,
    input wire rst,
    input wire signed [63:0] accumulator,
    input wire [5:0] shamt_data,
    input wire shamt_wr_en,
    input wire mode4x4,
    output reg signed [7:0] activation_in
);

    reg [5:0] shamt;

    always @(posedge clk or negedge rst) begin
        if (!rst)
            shamt <= 6'b000000;
        else if (shamt_wr_en)
            shamt <= shamt_data;
    end

    wire signed [64:0] padded_data = {accumulator, 1'b0};
    wire signed [64:0] coarse_shifted = padded_data >>> {shamt[5:3], 3'b000};
    wire signed [64:0] fine_shifted = coarse_shifted >>> shamt[2:0];

    wire round_bit = fine_shifted[0];
    wire [7:0] pre_round_8bit = fine_shifted[8:1];
    wire [7:0] rounded_8bit = pre_round_8bit + round_bit;

    wire [56:0] upper_57 = fine_shifted[64:8];
    wire nor_tree_57 = ~|upper_57;
    wire and_tree_57 = &upper_57;

    wire [3:0] mid_4 = fine_shifted[7:4];
    wire nor_tree_mid = ~|mid_4;
    wire and_tree_mid = &mid_4;

    wire nor_tree_61 = nor_tree_57 & nor_tree_mid;
    wire and_tree_61 = and_tree_57 & and_tree_mid;

    wire trunc_ovf_8 = ~(nor_tree_57 | and_tree_57);
    wire trunc_ovf_4 = ~(nor_tree_61 | and_tree_61);

    wire round_ovf_8 = (~pre_round_8bit[7]) & rounded_8bit[7];
    wire round_ovf_4 = (~pre_round_8bit[3]) & rounded_8bit[3];

    wire clamp_max_pos_8 = (trunc_ovf_8 | round_ovf_8) & ~accumulator[63];
    wire clamp_min_neg_8 = trunc_ovf_8 & accumulator[63];

    wire clamp_max_pos_4 = (trunc_ovf_4 | round_ovf_4) & ~accumulator[63];
    wire clamp_min_neg_4 = trunc_ovf_4 & accumulator[63];

    always @(*) begin
        if (mode4x4) begin
            if (clamp_max_pos_4)
                activation_in = 8'sd7;
            else if (clamp_min_neg_4)
                activation_in = -8'sd8;
            else
                activation_in = {{4{rounded_8bit[3]}}, rounded_8bit[3:0]};
        end else begin
            if (clamp_max_pos_8)
                activation_in = 8'sd127;
            else if (clamp_min_neg_8)
                activation_in = -8'sd128;
            else
                activation_in = rounded_8bit;
        end
    end

endmodule