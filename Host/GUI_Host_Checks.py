import customtkinter as ctk
import serial
import threading
import random
import time
import sys

# Configure GUI Appearance
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class AdvancedValidationApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Neural PE - Advanced Hardware Validation")
        self.geometry("850x650")

        # --- Sidebar ---
        self.sidebar = ctk.CTkFrame(self, width=220, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        
        self.logo_label = ctk.CTkLabel(self.sidebar, text="Test Control", font=ctk.CTkFont(size=20, weight="bold"))
        self.logo_label.pack(padx=20, pady=(20, 10))

        # Port Selection
        self.port_label = ctk.CTkLabel(self.sidebar, text="COM Port:")
        self.port_label.pack(pady=(10, 0))
        self.port_menu = ctk.CTkOptionMenu(self.sidebar, values=["COM1", "COM2", "COM3", "COM4", "COM5"])
        self.port_menu.set("COM5")
        self.port_menu.pack(pady=(0, 20), padx=20)

        # Suite Selection
        self.suite_label = ctk.CTkLabel(self.sidebar, text="Select Test Suite:")
        self.suite_label.pack(pady=(10, 0))
        self.suite_menu = ctk.CTkOptionMenu(self.sidebar, values=[
            "17 Logic Edge Cases", 
            "500-Test Regression", 
            "Hardware Diagnostics"
        ])
        self.suite_menu.pack(pady=(0, 20), padx=20)

        # Buttons
        self.btn_run = ctk.CTkButton(self.sidebar, text="Run Suite", fg_color="green", command=self.start_test_thread)
        self.btn_run.pack(pady=10, padx=20)

        self.btn_clear = ctk.CTkButton(self.sidebar, text="Clear Console", command=self.clear_console)
        self.btn_clear.pack(pady=10, padx=20)

        # --- Console ---
        self.console = ctk.CTkTextbox(self, width=580, height=600, font=("Consolas", 13))
        self.console.pack(side="right", padx=20, pady=20)

    # --- GUI Helper Methods ---
    def log(self, msg):
        self.console.insert("end", f"{msg}\n")
        self.console.see("end")

    def clear_console(self):
        self.console.delete("0.0", "end")

    def start_test_thread(self):
        self.btn_run.configure(state="disabled")
        selected_suite = self.suite_menu.get()
        # Run hardware tests in a separate thread to prevent GUI freezing
        threading.Thread(target=self.run_master_controller, args=(selected_suite,), daemon=True).start()

    # --- Hardware Communication Methods ---
    def send_packet(self, ser, opcode, a, b):
        # Safety Masking: Prevents FPGA Opcode Overflow by forcing it to 5 bits
        safe_opcode = int(opcode) & 0x1F 
        packet = bytes([safe_opcode]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
        ser.write(packet)
        
        # SAFE SPEED: 0.05 seconds gives the FPGA UART plenty of time to clear buffers
        # This prevents "Byte Drops" when pe_ready goes low.
        time.sleep(0.05) 

    def read_res(self, ser):
        res = ser.read(1)
        if not res:
            return None
        # Interpret the byte as Two's Complement Signed Integer
        return int.from_bytes(res, 'big', signed=True)

    # --- Master Test Controller ---
    def run_master_controller(self, suite_name):
        self.log(f"=== Starting: {suite_name} ===")
        try:
            ser = serial.Serial(self.port_menu.get(), 115200, timeout=1)
            ser.reset_input_buffer()
        except Exception as e:
            self.log(f"CONNECTION ERROR: {e}")
            self.btn_run.configure(state="normal")
            return

        if suite_name == "17 Logic Edge Cases":
            self.run_logic_suite(ser)
        elif suite_name == "500-Test Regression":
            self.run_500_regression(ser)
        elif suite_name == "Hardware Diagnostics":
            self.run_diagnostics(ser)

        ser.close()
        self.log("\n=== Disconnected ===")
        self.btn_run.configure(state="normal")

    # ==========================================
    # SUITE 1: 17 Logic Edge Cases
    # ==========================================
    def run_logic_suite(self, ser):
        self.log(f"{'TEST NAME':<16} | {'EXP':<5} | {'ACT':<5} | {'RESULT'}")
        self.log("-" * 45)
        
        passed = 0

        def test_t1():
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 2, 5, 6)
            self.send_packet(ser, 7, 0, 0)
            return self.read_res(ser)
        

        def test_t2():
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 5, 8, 0)
            self.send_packet(ser, 2, 0, 0)
            self.send_packet(ser, 6, 0, 0)
            time.sleep(0.05)
            return self.read_res(ser)

        def test_t3():
            
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 5, 8, 0)
            self.send_packet(ser, 2, 127, 1)
            self.send_packet(ser, 6, 0, 0)
            time.sleep(0.05)
            return self.read_res(ser)

        def test_t4():
            self.send_packet(ser, 2, 10, 10)
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 7, 0, 0)
            return self.read_res(ser)

        def test_t7():
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 2, 5, 6)
            self.send_packet(ser, 31, 0, 0)
            self.send_packet(ser, 7, 0, 0)
            return self.read_res(ser)

        def test_t14():
            self.send_packet(ser, 1, 0, 0)
            self.send_packet(ser, 2, 5, 5)
            self.send_packet(ser, 4, 0, 1)
            self.send_packet(ser, 6, 0, 0)
            time.sleep(0.05)
            return self.read_res(ser)

        def test_t16():
            ser.write(b'\x02')
            time.sleep(0.01)
            self.send_packet(ser, 2, 2, 3)
            self.send_packet(ser, 7, 0, 0)
            return self.read_res(ser)

        tests = {
            "T1-Nominal": (30, test_t1),
            "T2-Max Limit": (127, test_t2),
            "T3-Min Clear": (0, test_t3),
            "T4-Hard Reset": (0, test_t4),
            "T7-Invalid Op": (30, test_t7),
            "T14-Scale Bug": (25, test_t14),
            "T16-UART Drop": (6, test_t16)
        }
        
        for name, (exp, func) in tests.items():
            try:
                act = func()
                act_str = str(act) if act is not None else "TIMEOUT"
                status = "PASS" if act == exp else "FAIL"
                if status == "PASS": 
                    passed += 1
                self.log(f"{name:<16} | {exp:<5} | {act_str:<5} | {status}")
            except Exception as e:
                self.log(f"{name:<16} | {exp:<5} | ERROR | EXCEPTION: {e}")
                
        self.log("-" * 45)
        self.log(f"Suite Complete. Passed: {passed}/{len(tests)}")
    # ==========================================
    # SUITE 2: 500-Test Regression
    # ==========================================
    def run_500_regression(self, ser):
        passed, failed, timeouts = 0, 0, 0
        self.send_packet(ser, 1, 0, 0)
        self.send_packet(ser, 5, 8, 0) # Force INT8 Mode
        
        for i in range(1, 501):
            a = random.randint(0, 15)
            b = random.randint(0, 15)
            
            raw_mult = a * b
            lower_8_bits = raw_mult & 0xFF 
            
            if lower_8_bits > 127:
                expected = lower_8_bits - 256
            else:
                expected = lower_8_bits
            
            self.send_packet(ser, 1, 0, 0) 
            self.send_packet(ser, 2, a, b) 
            
            time.sleep(0.02) # Pipeline stall
            
            self.send_packet(ser, 7, 0, 0) 
            actual = self.read_res(ser)
            
            if actual is None:
                timeouts += 1
                self.log(f"[FAIL-TIME] {i:03d}: A={a:2}, B={b:2}")
            elif actual == expected:
                passed += 1
                if i % 50 == 0:
                    self.log(f"[PASS] {i:03d}: A={a:2}, B={b:2} | Exp={expected:4} | Act={actual:4}")
            else:
                failed += 1
                self.log(f"[FAIL-MATH] {i:03d}: A={a:2}, B={b:2} | Raw={raw_mult} | Exp={expected:4} | Act={actual:4}")
                
        self.log(f"\n--- Regression Summary ---")
        self.log(f"Passed: {passed} | Failed: {failed} | Timeouts: {timeouts}")

    # ==========================================
    # SUITE 3: Hardware Diagnostics
    # ==========================================
    def run_diagnostics(self, ser):
        self.log("1. Testing Accumulator Latch (Multi-MAC)")
        self.send_packet(ser, 1, 0, 0)
        self.send_packet(ser, 2, 2, 2)
        self.send_packet(ser, 2, 3, 3)
        self.send_packet(ser, 7, 0, 0)
        res1 = self.read_res(ser)
        self.log(f"   Expected: 13 | Actual: {res1}")
        if res1 == 4:
            self.log("   [!] BUG: Controller failed to latch second MAC (WE Issue).")
        elif res1 is None:
            self.log("   [!] TIMEOUT: FPGA dropped bytes or Controller froze during back-to-back MACs.")
        
        self.log("\n2. Testing PPU Valid_Out Assertion")
        self.send_packet(ser, 1, 0, 0)
        self.send_packet(ser, 2, 10, 10)
        self.send_packet(ser, 6, 0, 0) # EXEC_PP
        res2 = self.read_res(ser)
        self.log(f"   Expected: 100 | Actual: {res2}")
        if res2 is None:
            self.log("   [!] BUG (DEADLOCK): PPU state machine locked. 'valid_out' is NOT triggering,")
            self.log("   causing the Controller to wait forever in the EXEC_PP state.")

if __name__ == "__main__":
    app = AdvancedValidationApp()
    app.mainloop()