`timescale 1ns / 1ps

module IO_Block (
    input wire clk,
    input wire rst,
    input wire [31:0] operand_A,
    input wire [31:0] operand_B,
    input wire valid_A,
    input wire valid_B,
    input wire chp_slct,

    input wire pe_ready,
    input wire ppu_en,
    input wire read_acc_en,
    input wire read_cfg_en,

    input wire [63:0] accumulator,
    input wire [7:0] activation_out,
    input wire [3:0] config_out,

    output wire [31:0] operand_A_reg,
    output wire [31:0] operand_B_reg,

    output wire [7:0]  data_out
);

// Input Register Bank
reg [31:0] operand_A_reg_r;
reg [31:0] operand_B_reg_r;

wire wr_en_A = valid_A & pe_ready & chp_slct;
wire wr_en_B = valid_B & pe_ready & chp_slct;

always @(posedge clk or negedge rst) begin
    if (!rst)
        operand_A_reg_r <= 32'b0;
    else if (wr_en_A)
        operand_A_reg_r <= operand_A;
end

always @(posedge clk or negedge rst) begin
    if (!rst)
        operand_B_reg_r <= 32'b0;
    else if (wr_en_B)
        operand_B_reg_r <= operand_B;
end

assign operand_A_reg = operand_A_reg_r;
assign operand_B_reg = operand_B_reg_r;

// Byte-Select Path
wire [63:0] acc_gated = accumulator & {64{read_acc_en}};

reg [7:0] byte_mux_out;

always @(*) begin
    case (operand_A_reg_r[2:0])
        3'd0: byte_mux_out = acc_gated[7:0];
        3'd1: byte_mux_out = acc_gated[15:8];
        3'd2: byte_mux_out = acc_gated[23:16];
        3'd3: byte_mux_out = acc_gated[31:24];
        3'd4: byte_mux_out = acc_gated[39:32];
        3'd5: byte_mux_out = acc_gated[47:40];
        3'd6: byte_mux_out = acc_gated[55:48];
        3'd7: byte_mux_out = acc_gated[63:56];
    endcase
end

wire act_sel = ~read_acc_en & ~read_cfg_en;

wire [7:0] output_mux_result =
      (byte_mux_out & {8{read_acc_en}})
    | ({4'b0, config_out} & {8{read_cfg_en}})
    | (activation_out & {8{act_sel}});

// Output Register
wire output_wr_en = ppu_en | read_acc_en | read_cfg_en;

reg [7:0] data_out_r;

always @(posedge clk or negedge rst) begin
    if (!rst)
        data_out_r <= 8'b0;
    else if (output_wr_en)
        data_out_r <= output_mux_result;
end

assign data_out = data_out_r;

endmodule