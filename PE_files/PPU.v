module PPU (
    input wire clk,
    input wire rst,
    input wire signed [63:0] accumulator,
    input wire [5:0] shamt_data,
    input wire shamt_wr_en,
    input wire mode4x4,
    input wire [2:0] act_fn_sel,
    input wire ppu_en,
    output wire [7:0] activation_out
);

    wire signed [63:0] accumulator_g = accumulator & {64{ppu_en}};

    // Stage 1: Requantizer

    wire signed [7:0] activation_in;

    Requantizer u_requantizer (
        .clk (clk),
        .rst (rst),
        .accumulator (accumulator_g),
        .shamt_data (shamt_data),
        .shamt_wr_en (shamt_wr_en),
        .mode4x4 (mode4x4),
        .activation_in (activation_in)
    );

    // Stage 2: Activation Block
    
    Activation_Block u_activation_block (
        .activation_in (activation_in),
        .mode4x4 (mode4x4),
        .act_fn_sel (act_fn_sel),
        .activation_out (activation_out)
    );

endmodule