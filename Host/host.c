#include <stdio.h>
#include <stdint.h>
// host code 
typedef struct {
    uint32_t operand_A; // 32-bit packed INT4/INT8 
    uint32_t operand_B; // 32-bit packed INT4/INT8 or Bias 
    uint8_t  op_code;   // 5-bit instruction
} PE_Inputs;

void send_pe_command(int serial_fd, PE_input inpt) {
    uint8_t buffer[9]; // 4 bytes A + 4 bytes B + 1 byte Opcode

    // Pack Operand A (Big Endian or Little Endian depending on FPGA logic)
    buffer[0] = (pkt.operand_A >> 24) & 0xFF;
    buffer[1] = (pkt.operand_A >> 16) & 0xFF;
    buffer[2] = (pkt.operand_A >> 8) & 0xFF;
    buffer[3] = pkt.operand_A & 0xFF;

    // Pack Operand B
    buffer[4] = (pkt.operand_B >> 24) & 0xFF;
    buffer[5] = (pkt.operand_B >> 16) & 0xFF;
    buffer[6] = (pkt.operand_B >> 8) & 0xFF;
    buffer[7] = pkt.operand_B & 0xFF;

    // Pack Opcode
    buffer[8] = pkt.op_code & 0x1F; // 5-bit mask [cite: 42]

    // Send the 9-byte packet
    write(serial_fd, buffer, 9);
    
    // Wait for the response to verify the "shell" works
    uint8_t result;
    read(serial_fd, &result, 1);
    printf("PE Result Received: %d\n", result);
}