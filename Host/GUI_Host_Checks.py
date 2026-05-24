import serial
import time
import random

import sys
import serial
import time
import sys

class MasterSystemValidator:
    def __init__(self, port='COM5'):
        try:
            self.ser = serial.Serial(port, 115200, timeout=1)
            self.ser.reset_input_buffer()
            print(f"Successfully connected to {port}")
        except Exception as e:
            print(f"Critical Connection Error: {e}")
            sys.exit()

    def send(self, opcode, a, b):
        # Pack opcode and operands (signed 32-bit big-endian)
        packet = bytes([int(opcode)]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
        self.ser.write(packet)
        time.sleep(0.03) # Required delay for FPGA processing

    def read_res(self):
        # Read the 1-byte response from FPGA
        res = self.ser.read(1)
        if not res:
            return None
        return int.from_bytes(res, 'big', signed=True)

    def run_tests(self):
        # 17-Test Mapping
        tests = {
            "T1-Nominal": (30, lambda: self.send(1,0,0) or self.send(2,5,6) or self.send(7,0,0) or self.read_res()),
            "T2-Max": (127, lambda: self.send(1,0,0) or self.send(5,8,0) or self.send(2,127,1) or self.send(6,0,0) or self.read_res()),
            "T3-Min": (0, lambda: self.send(1,0,0) or self.send(5,8,0) or self.send(2,0,0) or self.send(6,0,0) or self.read_res()),
            "T4-Reset": (0, lambda: self.send(2,10,10) or self.send(1,0,0) or self.send(7,0,0) or self.read_res()),
            "T5-MidOpReset": (0, lambda: self.send(2,10,10) or self.send(1,0,0) or self.read_res()),
            "T6-ValidOp": (30, lambda: self.send(2,5,6) or self.send(7,0,0) or self.read_res()),
            "T7-InvalidOp": (30, lambda: self.send(31,0,0) or self.send(7,0,0) or self.read_res()),
            "T8-BusyStall": (30, lambda: self.send(2,10,10) or self.send(2,5,5) or self.send(7,0,0) or self.read_res()),
            "T9-InstantCmd": (30, lambda: self.send(2,5,6) or self.send(7,0,0) or self.read_res()),
            "T10-Timing": (30, lambda: self.send(2,5,6) or time.sleep(0.1) or self.send(7,0,0) or self.read_res()),
            "T11-BackToBack": (30, lambda: self.send(2,5,6) or self.send(2,2,2) or self.send(7,0,0) or self.read_res()),
            "T12-Noise": (30, lambda: self.send(2,5,6) or self.send(99,0,0) or self.send(7,0,0) or self.read_res()),
            "T13-CRV": (127, lambda: self.send(2,127,1) or self.send(6,0,0) or self.read_res()),
            "T14-ScaleBug": (25, lambda: self.send(1,0,0) or self.send(2,5,5) or self.send(4,0,1) or self.send(6,0,0) or self.read_res()),
            "T15-Delayed": (12, lambda: self.send(1,0,0) or self.send(2,3,4) or time.sleep(0.1) or self.send(7,0,0) or self.read_res()),
            "T16-Interrupted": (6, lambda: self.ser.write(b'\x02') or time.sleep(0.01) or self.send(2,2,3) or self.send(7,0,0) or self.read_res()),
            "T17-NonContinuous": (20, lambda: self.send(1,0,0) or self.send(2,4,5) or self.send(7,0,0) or self.read_res())
        }

        print(f"\n{'TEST NAME':<18} | {'EXP':<5} | {'ACT':<5} | {'RESULT'}")
        print("-" * 45)
        
        passed = 0
        for name, (exp, func) in tests.items():
            act = func()
            act_str = str(act) if act is not None else "TIMEOUT"
            status = "PASS" if act == exp else "FAIL"
            if status == "PASS": passed += 1
            print(f"{name:<18} | {exp:<5} | {act_str:<5} | {status}")
        
        print("-" * 45)
        print(f"Validation Finished. Total Passed: {passed}/17\n")
        self.ser.close()

if __name__ == "__main__":
    validator = MasterSystemValidator(port='COM5')
    validator.run_tests()

'''
class MasterValidator:
    def __init__(self, port='COM5'):
        try:
            self.ser = serial.Serial(port, 115200, timeout=1)
            self.ser.reset_input_buffer()
            print(f"Connected to {port}")
        except Exception as e:
            print(f"Connection Error: {e}")
            sys.exit()

    def send(self, opcode, a, b):
        # Pack opcode and operands (signed 32-bit big-endian)
        packet = bytes([int(opcode)]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
        self.ser.write(packet)
        time.sleep(0.02) # Delay to ensure hardware readiness

    def read_res(self):
        res = self.ser.read(1)
        return int.from_bytes(res, 'big', signed=True) if res else None

    def run_full_suite(self):
        print("\n--- STARTING MASTER VERIFICATION SUITE ---")
        self.run_edge_cases()
        self.ser.close()
        print("\n--- VALIDATION COMPLETE ---")

    

    def run_edge_cases(self):
        print("\n[PHASE 2] Running Edge Case Suite:")
        
        # Test: Max Values (Saturation)
        self.send(1, 0, 0); self.send(5, 8, 0); self.send(2, 127, 1); self.send(6, 0, 0)
        actual = self.read_res()
        print(f"Max Value (127*1): Got {actual} | {'PASS' if actual == 127 else 'FAIL'}")

        # Test: Illegal Opcode (31)
        self.send(1, 0, 0); self.send(2, 5, 5); self.send(31, 0, 0); self.send(7, 0, 0)
        actual = self.read_res()
        print(f"Illegal Op (31) Integrity: Got {actual} | {'PASS' if actual == 25 else 'FAIL'}")

        # Test: Reset Recovery
        self.send(2, 10, 10); self.send(1, 0, 0); self.send(7, 0, 0)
        actual = self.read_res()
        print(f"Reset Recovery: Got {actual} | {'PASS' if actual == 0 else 'FAIL'}")

if __name__ == "__main__":
    validator = MasterValidator()
    validator.run_full_suite()

class PEValidator:
    def __init__(self, port='COM5'):
        self.ser = serial.Serial(port, 115200, timeout=1)
        self.ser.reset_input_buffer()

    def send(self, opcode, a, b):
        packet = bytes([int(opcode)]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
        self.ser.write(packet)
        time.sleep(0.02)

    def read_res(self):
        res = self.ser.read(1)
        return int.from_bytes(res, 'big', signed=True) if res else None

    # --- TESTS ---
    def test_max_min(self):
        # Test Max: 127 * 1 = 127
        self.send(1, 0, 0); self.send(5, 8, 0); self.send(2, 127, 1); self.send(7, 0, 0)
        actual = self.read_res()
        print(f"[MAX TEST] Expected 127, Got {actual} -> {'PASS' if actual == 127 else 'FAIL'}")

        # Test Min: 0 * 0 = 0
        self.send(1, 0, 0); self.send(2, 0, 0); self.send(7, 0, 0)
        actual = self.read_res()
        print(f"[MIN TEST] Expected 0, Got {actual} -> {'PASS' if actual == 0 else 'FAIL'}")

    def test_illegal_opcode(self):
        self.send(1, 0, 0); self.send(2, 5, 5) # Acc = 25
        self.send(31, 0, 0) # Invalid
        self.send(7, 0, 0)
        actual = self.read_res()
        print(f"[ILLEGAL OP] Expected 25, Got {actual} -> {'PASS' if actual == 25 else 'FAIL'}")

    def test_reset_recovery(self):
        self.send(2, 10, 10) # Acc = 100
        self.send(1, 0, 0)   # Abort/Reset
        self.send(7, 0, 0)
        actual = self.read_res()
        print(f"[RESET RECOVERY] Expected 0, Got {actual} -> {'PASS' if actual == 0 else 'FAIL'}")

    def test_overflow(self):
        # Accumulator overflow: 100 * 10 = 1000 (exceeds INT8)
        self.send(1, 0, 0); self.send(5, 8, 0); self.send(2, 100, 10); self.send(6, 0, 0)
        actual = self.read_res()
        print(f"[OVERFLOW] Saturation Check, Got {actual}")

    def run_all(self):
        print("--- Starting Full Edge Case Suite ---")
        self.test_max_min()
        self.test_illegal_opcode()
        self.test_reset_recovery()
        self.test_overflow()
        self.ser.close()

if __name__ == "__main__":
    validator = PEValidator()
    validator.run_all()
    '''