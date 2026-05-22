`timescale 1ns / 1ps

module Controller (
    input wire clk,
    input wire rst,

    // External instruction interface
    input wire [4:0] pe_opcode,
    input wire chp_slct,
    input wire valid_opcode,

    input wire [3:0] cfg_data_in,

    // MAC & SCALE control
    output wire mode4x4,
    output wire a_is_signed,
    output wire b_is_signed,
    output wire scale_mode,
    output wire [1:0] scale_phase,
    output wire mac4_en,
    output wire mac8_en,
    output wire [1:0] acc_source,
    output wire acc_wr_en,
    output wire acc_load,
    output wire rst_acc,

    // PPU control
    output wire ppu_en,
    output wire shamt_wr_en,
    output wire [2:0] act_fn_sel,

    // I/O control and top-level status
    output wire read_acc_en,
    output wire read_cfg_en,
    output wire [3:0] config_out,
    output wire pe_ready,
    output wire valid_output
);

// Opcode encodings
localparam [4:0] NOP = 5'b00000;
localparam [4:0] RST_ACC = 5'b00001;
localparam [4:0] MAC = 5'b00010;
localparam [4:0] ADD_BIAS = 5'b00011;
localparam [4:0] SCALE = 5'b00100;
localparam [4:0] LOAD_CFG = 5'b00101;
localparam [4:0] EXEC_PP = 5'b00110;
localparam [4:0] READ_ACC_BYTE = 5'b00111;
localparam [4:0] READ_CFG = 5'b01000;

// FSM state encodings
localparam [1:0] IDLE = 2'b00;
localparam [1:0] SC1 = 2'b01;
localparam [1:0] SC2 = 2'b10;
localparam [1:0] SC3 = 2'b11;


// Instruction Fetch
reg [4:0] opcode_reg;
wire capture_gate = pe_ready & valid_opcode & chp_slct;

always @(posedge clk or negedge rst) begin
    if (!rst)
        opcode_reg <= NOP;
    else
        opcode_reg <= capture_gate ? pe_opcode : NOP;
end

reg [4:0] validated_cmd;

always @(*) begin
    case (opcode_reg)
        NOP,
        RST_ACC,
        MAC,
        ADD_BIAS,
        SCALE,
        LOAD_CFG,
        EXEC_PP,
        READ_ACC_BYTE,
        READ_CFG: validated_cmd = opcode_reg;
        default:  validated_cmd = NOP;
    endcase
end

reg [3:0] config_reg;
wire cfg_wr_en = (validated_cmd == LOAD_CFG);

always @(posedge clk or negedge rst) begin
    if (!rst)
        config_reg <= 4'b0000;
    else if (cfg_wr_en)
        config_reg <= cfg_data_in;
end

assign act_fn_sel = config_reg[2:0];
assign config_out = config_reg[3:0];

// SCALE Sequencer (FSM)
reg [1:0] state, next_state;

always @(posedge clk or negedge rst) begin
    if (!rst)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: next_state = (validated_cmd == SCALE) ? SC1 : IDLE;
        SC1: next_state = SC2;
        SC2: next_state = SC3;
        SC3: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

assign pe_ready = (!rst) | ((next_state == IDLE) & (opcode_reg != SCALE));

reg valid_output_reg;

always @(posedge clk or negedge rst) begin
    if (!rst)
        valid_output_reg <= 1'b0;
    else
        valid_output_reg <= (ppu_en | read_acc_en | read_cfg_en);
end

assign valid_output = valid_output_reg;


// Instruction Decoder

// Single-cycle command predicates (gated by state == IDLE)
wire cmd_is_rst_acc = (state == IDLE) & (validated_cmd == RST_ACC);
wire cmd_is_mac = (state == IDLE) & (validated_cmd == MAC);
wire cmd_is_bias = (state == IDLE) & (validated_cmd == ADD_BIAS);
wire cmd_is_scale0 = (state == IDLE) & (validated_cmd == SCALE);
wire cmd_is_exec_pp = (state == IDLE) & (validated_cmd == EXEC_PP);
wire cmd_is_read_acc = (state == IDLE) & (validated_cmd == READ_ACC_BYTE);
wire cmd_is_read_cfg = (state == IDLE) & (validated_cmd == READ_CFG);

// SCALE state predicates
wire in_sc1 = (state == SC1);
wire in_sc2 = (state == SC2);
wire in_sc3 = (state == SC3);

wire any_scale = cmd_is_scale0 | in_sc1 | in_sc2 | in_sc3;

// Multiplier Configuration
assign mode4x4 = ~any_scale & ~config_reg[3];

assign a_is_signed = cmd_is_mac | in_sc3;
assign b_is_signed = cmd_is_mac;

// Input Routing
assign scale_mode = any_scale;

// scale_phase: 00 (cyc0) / 01 (SC1) / 10 (SC2) / 11 (SC3)
assign scale_phase[1] = in_sc2 | in_sc3;
assign scale_phase[0] = in_sc1 | in_sc3;

// Operand Isolation
assign mac4_en = cmd_is_mac & ~config_reg[3];
assign mac8_en = cmd_is_mac & config_reg[3];

// Accumulator Control
// acc_source: 00 = INT4 MAC, 01 = INT8 MAC, 10 = SCALE partial, 11 = bias
assign acc_source[1] = any_scale | cmd_is_bias;
assign acc_source[0] = (cmd_is_mac & config_reg[3]) | cmd_is_bias;

assign acc_wr_en = cmd_is_mac | cmd_is_bias | any_scale;
assign rst_acc = cmd_is_rst_acc;

assign shamt_wr_en = cmd_is_scale0;
assign acc_load = cmd_is_scale0;

// PPU and Output Path Control
assign ppu_en = cmd_is_exec_pp;
assign read_acc_en = cmd_is_read_acc;
assign read_cfg_en = cmd_is_read_cfg;

endmodule