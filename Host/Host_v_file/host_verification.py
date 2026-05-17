import serial
import struct
import time
import random

PORT = 'COM3'  # Update with your active OS COM line mapping
BAUD = 115200
TIMEOUT = 3.0

def establish_link():
    ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
    time.sleep(1.5) # Await physical line driver initialization
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return ser

def execute_dut_transaction(ser, chp_slct, valid_in, op_code, operand_a, operand_b):
    """
    Constructs and sends a 9-byte packet to the FPGA.
    Format: [Control Byte, 4-byte Operand A, 4-byte Operand B]
    """
    # Build structural control byte matching the system bridge unpack format
    ctrl_byte = (int(chp_slct) << 7) | (int(valid_in) << 6) | (op_code & 0x07)
    
    # Pack parameters into a sequence of raw Big-Endian values
    payload = struct.pack('>BII', ctrl_byte, operand_a, operand_b)
    ser.write(payload)
    ser.flush()
    
    # Capture feedback tracking bytes
    status_frame = ser.read(1)
    data_frame = ser.read(1)
    
    if len(status_frame) == 1 and len(data_frame) == 1:
        status = ord(status_frame)
        pe_out = ord(data_frame)
        dut_busy = bool(status & 0x80)
        dut_valid_out = bool(status & 0x40)
        return {"busy": dut_busy, "valid_out": dut_valid_out, "result": pe_out}
    else:
        raise TimeoutError("DUT dropped transaction window. Check structural pin layout.")

# DIRECTED VERIFICATION SUITE

def run_directed_tests(ser):
    print("\n--- Running Directed Verification Suite ---")
    
    # Test 1: Basic Load & Hold [Specification Section 2]
    print("[TEST 1] Testing basic Load & Hold...")
    res = execute_dut_transaction(ser, chp_slct=True, valid_in=True, op_code=0, operand_a=0xAAAAAAAA, operand_b=0x55555555)
    print(f"         Status Captured -> Busy: {res['busy']}, Valid Out: {res['valid_out']}, Readout: 0x{res['result']:02X}")
    
    # Test 2: Chip Select (chp_slct) Gating [Specification Section 2]
    print("[TEST 2] Testing Chip Select gating (Should maintain previous state)...")
    res = execute_dut_transaction(ser, chp_slct=False, valid_in=True, op_code=1, operand_a=0xFFFFFFFF, operand_b=0xFFFFFFFF)
    print(f"         Status Captured -> Busy: {res['busy']}, Valid Out: {res['valid_out']}, Readout: 0x{res['result']:02X}")


# CONSTRAINED RANDOM SUITE

def run_constrained_random_tests(ser, iterations=50):
    print(f"\n--- Running Constrained Random Verification Suite ({iterations} Iterations) ---")
    print("[TEST 3] Injecting randomized 32-bit matrices for toggle coverage...")
    
    success_runs = 0
    for idx in range(iterations):
        rand_a = random.randint(0, 0xFFFFFFFF)
        rand_b = random.randint(0, 0xFFFFFFFF)
        rand_op = random.choice([0, 1]) # e.g., alternating between MAC4 and MAC8 modes
        
        try:
            res = execute_dut_transaction(ser, chp_slct=True, valid_in=True, op_code=rand_op, operand_a=rand_a, operand_b=rand_b)
            success_runs += 1
        except TimeoutError:
            print(f"         [FAIL] Communication collapsed at step sequence {idx}")
            break
            
    print(f"         Toggle Verification Run Complete: {success_runs}/{iterations} streams executed successfully.")

if __name__ == '__main__':
    print("  ----  PE Automated Hardware Verification Bench  ---- ")
    connection = establish_link()
    
    run_directed_tests(connection)
    run_constrained_random_tests(connection, iterations=100)
    
    connection.close()
    print("\n[INFO] Test execution cycle terminated.")