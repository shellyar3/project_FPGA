import serial
import time

PORT = 'COM5'
BAUD_RATE = 115200

# Directory of 5-bit hardware configurations mapped directly to our RTL values
OPERATIONS = {
    0: {"name": "ADD", "A": 45, "B": 15, "expected": 60},
    1: {"name": "SUB", "A": 100, "B": 30, "expected": 70},
    2: {"name": "MUL", "A": 6,   "B": 8,  "expected": 48},  
    3: {"name": "AND", "A": 0xFF, "B": 0x0F, "expected": 0x0F},
    4: {"name": "OR",  "A": 0xF0, "B": 0x0F, "expected": 0xFF},
    5: {"name": "MAC", "A": 4,   "B": 3,  "expected": 14},  # (4*3) + 2 = 14
}

def run_targeted_suite():
    print(f"==================================================")
    print(f"RUNNING TARGETED 5-BIT ALU/PE VERIFICATION SUITE")
    print(f"==================================================")
    
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=1.5)
        time.sleep(1.5) 
        
        for opcode, info in OPERATIONS.items():
            val_A = info["A"]
            val_B = info["B"]
            
            # Pack the 5-bit Opcode into the Header Byte (Bit 7: CS, Bit 6: Valid)
            header_value = 0xC0 | (opcode & 0x1F)
            header = bytes([header_value])
            
            # Stream translation to Big-Endian 32-bit registers
            op_A_bytes = val_A.to_bytes(4, byteorder='big')
            op_B_bytes = val_B.to_bytes(4, byteorder='big')
            
            tx_packet = header + op_A_bytes + op_B_bytes
            
            ser.reset_input_buffer()
            ser.write(tx_packet)
            ser.flush()
            
            time.sleep(0.05) 
            response = ser.read(2)
            
            if len(response) == 2:
                actual_result = response[1]
                if actual_result == info["expected"]:
                    print(f"Opcode {opcode:02d} ({info['name']:<4}): PASSED ✅ | Sent: A={val_A:<3} B={val_B:<3} | Got: {actual_result}")
                else:
                    print(f"Opcode {opcode:02d} ({info['name']:<4}): FAILED ❌ | Expected {info['expected']}, Got {actual_result}")
            else:
                print(f"Opcode {opcode:02d} ({info['name']:<4}): TIMEOUT ⚠️ | No reply from FPGA")
                
        ser.close()
        print(f"==================================================")
        
    except Exception as e:
        print(f"Serial Error: {e}")

if __name__ == "__main__":
    run_targeted_suite()