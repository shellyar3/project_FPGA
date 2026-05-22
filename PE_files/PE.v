`timescale 1ns / 1ps

//=============================================================================
// Module      : PE
// Description : Processing Element top-level. Instantiates and wires together
//               the Controller, MAC & SCALE datapath, Post-Processing Unit,
//               and I/O Block per the PE Top-Level Microarchitecture document.
//=============================================================================

module PE (
    input wire clk,
    input wire rst,

    // External instruction interface
    input wire chp_slct,
    input wire valid_opcode,
    input wire [4:0] pe_opcode,

    // External operand interface
    input wire valid_A,
    input wire valid_B,
    input wire [31:0] operand_A,
    input wire [31:0] operand_B,

    // External outputs
    output wire [7:0] data_out,
    output wire pe_ready,
    output wire valid_output
);

    //-------------------------------------------------------------------------
    // Inter-module nets
    //-------------------------------------------------------------------------

    // Controller -> MAC & SCALE
    wire mode4x4;
    wire a_is_signed;
    wire b_is_signed;
    wire scale_mode;
    wire [1:0] scale_phase;
    wire mac4_en;
    wire mac8_en;
    wire [1:0] acc_source;
    wire acc_wr_en;
    wire acc_load;
    wire rst_acc;

    // Controller -> PPU
    wire ppu_en;
    wire shamt_wr_en;
    wire [2:0] act_fn_sel;

    // Controller -> I/O Block
    wire read_acc_en;
    wire read_cfg_en;
    wire [3:0] config_out;

    // I/O Block -> Datapath
    wire [31:0] operand_A_reg;
    wire [31:0] operand_B_reg;

    // MAC & SCALE -> PPU, I/O Block
    wire [63:0] accumulator;

    // PPU -> I/O Block
    wire[7:0] activation_out;

    // Reset Synchronizer -> All Modules
    wire sync_rst;

    //-------------------------------------------------------------------------
    // Controller
    //-------------------------------------------------------------------------
    Controller u_controller (
        .clk (clk),
        .rst (sync_rst),

        .pe_opcode (pe_opcode),
        .chp_slct (chp_slct),
        .valid_opcode (valid_opcode),
        .cfg_data_in (operand_A_reg[3:0]),

        .mode4x4 (mode4x4),
        .a_is_signed (a_is_signed),
        .b_is_signed (b_is_signed),
        .scale_mode (scale_mode),
        .scale_phase (scale_phase),
        .mac4_en (mac4_en),
        .mac8_en (mac8_en),
        .acc_source (acc_source),
        .acc_wr_en (acc_wr_en),
        .acc_load (acc_load),
        .rst_acc (rst_acc),

        .ppu_en (ppu_en),
        .shamt_wr_en (shamt_wr_en),
        .act_fn_sel (act_fn_sel),

        .read_acc_en (read_acc_en),
        .read_cfg_en (read_cfg_en),
        .config_out (config_out),
        .pe_ready (pe_ready),
        .valid_output (valid_output)
    );

    //-------------------------------------------------------------------------
    // MAC & SCALE
    //-------------------------------------------------------------------------
    MAC_and_SCALE u_mac_and_scale (
        .clk (clk),
        .rst (sync_rst),

        .port_A (operand_A_reg),
        .port_B (operand_B_reg),
        .accumulator (accumulator),

        .mode4x4 (mode4x4),
        .a_is_signed (a_is_signed),
        .b_is_signed (b_is_signed),
        .scale_mode  (scale_mode),
        .scale_phase (scale_phase),
        .mac4_en (mac4_en),
        .mac8_en (mac8_en),
        .acc_source (acc_source),
        .acc_wr_en (acc_wr_en),
        .acc_load (acc_load),
        .rst_acc (rst_acc)
    );

    //-------------------------------------------------------------------------
    // PPU
    //-------------------------------------------------------------------------
    PPU u_ppu (
        .clk (clk),
        .rst (sync_rst),
        .accumulator (accumulator),
        .shamt_data (operand_A_reg[5:0]),
        .shamt_wr_en (shamt_wr_en),
        .mode4x4 (mode4x4),
        .act_fn_sel (act_fn_sel),
        .ppu_en (ppu_en),
        .activation_out (activation_out)
    );

    //-------------------------------------------------------------------------
    // I/O Block
    //-------------------------------------------------------------------------
    IO_Block u_io_block (
        .clk (clk),
        .rst (sync_rst),

        .operand_A (operand_A),
        .operand_B (operand_B),
        .valid_A (valid_A),
        .valid_B (valid_B),
        .chp_slct (chp_slct),

        .pe_ready (pe_ready),
        .ppu_en (ppu_en),
        .read_acc_en (read_acc_en),
        .read_cfg_en (read_cfg_en),

        .accumulator (accumulator),
        .activation_out (activation_out),
        .config_out (config_out),

        .operand_A_reg (operand_A_reg),
        .operand_B_reg (operand_B_reg),
        .data_out (data_out)
    );

    //-------------------------------------------------------------------------
    // AASD Reset Synchronizer
    //-------------------------------------------------------------------------
    reset_sync u_reset_sync (
        .clk (clk),
        .async_rst (rst),
        .sync_rst (sync_rst) 
    );

endmodule
