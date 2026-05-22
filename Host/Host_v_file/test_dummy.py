import serial
import time
import random

PORT = 'COM5'
BAUD_RATE = 115200
NUM_TESTS = 20  # Number of random operations to run

def run_verification_suite():
    print(f"==================================================")
    print(f"STARTING HARDWARE DUMMY PE VERIFICATION SUITE")
    print(f"Target Port: {PORT} | Total Test Iterations: {NUM_TESTS}")
    print(f"==================================================")
    
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=1)
        time.sleep(1.5) # Allow driver to stabilize
        
        passed_tests = 0
        
        for i in range(1, NUM_TESTS + 1):
            # 1. Generate random 32-bit integer values (restricted to 0-100 for easy dummy overflow safety)
            val_A = random.randint(0, 100)
            val_B = random.randint(0, 100)
            
            # The dummy PE simply adds the lower 8-bits: (A + B) & 0xFF
            expected_result = (val_A + val_B) & 0xFF
            
            # 2. Package into big-endian byte structures
            header = b'\xC0' # chp_slct=1, valid_in=1
            op_A_bytes = val_A.to_bytes(4, byteorder='big')
            op_B_bytes = val_B.to_bytes(4, byteorder='big')
            tx_packet = header + op_A_bytes + op_B_bytes
            
            # 3. Clear buffers and send
            ser.reset_input_buffer()
            ser.write(tx_packet)
            ser.flush()
            
            # Small execution window delay
            time.sleep(0.05)
            
            # 4. Read response
            response = ser.read(2)
            
            if len(response) == 2:
                status_byte = response[0]
                actual_result = response[1]
                
                # Check calculation accuracy
                if actual_result == expected_result:
                    print(f"Test {i:02d}: PASSED | A={val_A:<3} B={val_B:<3} | Expected={expected_result:<3} Got={actual_result:<3}")
                    passed_tests += 1
                else:
                    print(f"Test {i:02d}: FAILED ❌ | A={val_A:<3} B={val_B:<3} | Expected={expected_result:<3} Got={actual_result:<3}")
            else:
                print(f"Test {i:02d}: TIMEOUT ⚠️ | Hardware failed to respond in time.")
                
        ser.close()
        
        # Final Report Summary
        print(f"==================================================")
        print(f"VERIFICATION SUITE COMPLETE")
        print(f"Passed: {passed_tests}/{NUM_TESTS} ({passed_tests/NUM_TESTS*100:.1f}%)")
        print(f"==================================================")
        
    except Exception as e:
        print(f"Error during execution: {e}")

if __name__ == "__main__":
    run_verification_suite()