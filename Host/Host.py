import serial
import time
import numpy as np

# =====================================================================
# 1. HARDWARE CONFIGURATION & INITIALIZATION
# =====================================================================
COM_PORT = 'COM5'
BAUD_RATE = 115200

# Opcodes
OP_RST_ACC    = 1
OP_MAC        = 2
OP_EXEC_PP    = 6
OP_LOAD_CFG   = 8

def send_cmd(ser, a, b, opcode):
    """Streams a 9-byte packet over UART to the DE10-Lite."""
    a_bytes = int(a).to_bytes(4, byteorder='big', signed=True)
    b_bytes = int(b).to_bytes(4, byteorder='big', signed=True)
    packet = bytearray([opcode]) + bytearray(a_bytes) + bytearray(b_bytes)
    ser.write(packet)
    time.sleep(0.005) # Brief pause to prevent buffer overflow

def wait_for_valid(ser, timeout_seconds=2.0):
    """Polls the RX line waiting for the hardware 'Done' byte."""
    timeout = time.time() + timeout_seconds
    while time.time() < timeout:
        if ser.in_waiting > 0:
            return ser.read(1)[0]
    return None

if __name__ == '__main__':
    try:
        print("==================================================")
        print(" Neural PE Hardware-in-the-Loop (HIL) Testbench")
        print("==================================================")
        
        ol = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
        print(f"✓ UART Bridge connected successfully on {COM_PORT}.")

        # =====================================================================
        # 2. DATA PREPARATION & GOLDEN MODEL VERIFICATION
        # =====================================================================
        print("\nPreparing Input Data Vectors...")
        
        # Simulating a small vector dot-product (1x5)
        # You can replace this with random np arrays later for deep testing
        vector_A = np.array([1, 2, 3, 4, 5], dtype=np.int32)
        vector_B = np.array([2, 2, 2, 2, 2], dtype=np.int32)
        
        # Compute the Golden Software Output 
        golden_output = np.dot(vector_A, vector_B)
        print(f"Golden Software Reference Output: {golden_output}")

        # =====================================================================
        # 3. HARDWARE CONFIGURATION
        # =====================================================================
        print("\nStreaming configuration to Processing Element...")
        
        # Disable Requantizer shifting (Shift = 0) so we get the raw accumulator
        send_cmd(ol, 0, 0, OP_LOAD_CFG)
        
        # Wipe the accumulator memory clean
        send_cmd(ol, 0, 0, OP_RST_ACC)

        # =====================================================================
        # 4. HARDWARE EXECUTION TRIGGER
        # =====================================================================
        print("Starting FPGA MAC array stream...")
        start_time = time.time()

        # Stream the vectors through the Neural PE
        for i in range(len(vector_A)):
            send_cmd(ol, vector_A[i], vector_B[i], OP_MAC)

        # Pulse the Execution trigger to output the final answer
        send_cmd(ol, 0, 0, OP_EXEC_PP)
        
        # Wait for the UART bridge to send the 1-byte answer back
        hw_output = wait_for_valid(ol)

        hw_duration = (time.time() - start_time) * 1000
        print(f"✓ FPGA Inference completed in {hw_duration:.2f} ms.")

        # =====================================================================
        # 5. TEST VERIFICATION
        # =====================================================================
        print("\n================ Verification ==================")
        if hw_output is None:
            print("[FAILURE] Hardware timed out. No response received.")
            
        elif hw_output == golden_output:
            print(f"[SUCCESS] TEST PASSED: FPGA math perfectly matches Golden Model.")
            print(f"    -> Hardware Output: {hw_output} | Golden Output: {golden_output}")
            
        else:
            print(f"[FAILURE] TEST FAILED: Hardware mismatch detected.")
            print(f"    -> Hardware Output: {hw_output} | Golden Output: {golden_output}")

        # =====================================================================
        # 6. CLEANUP
        # =====================================================================
        ol.close()
        print("\nSerial connection closed safely.")

    except serial.SerialException as e:
        print(f"\n[ERROR] Failed to connect to {COM_PORT}: {e}")