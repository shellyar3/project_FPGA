import customtkinter as ctk
import serial
import threading
import random
import time

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class SimplifiedValidationApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Neural PE - Line-by-Line Validation")
        self.geometry("700x600")

        # --- Sidebar ---
        self.sidebar = ctk.CTkFrame(self, width=200, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        
        self.port_menu = ctk.CTkOptionMenu(self.sidebar, values=["COM1", "COM2", "COM3", "COM4", "COM5"])
        self.port_menu.set("COM5")
        self.port_menu.pack(pady=20, padx=20)

        self.btn_run = ctk.CTkButton(self.sidebar, text="Run 100 Tests", fg_color="green", command=self.start_test_thread)
        self.btn_run.pack(pady=20, padx=20)

        # --- Console ---
        self.console = ctk.CTkTextbox(self, width=480, height=560, font=("Consolas", 13))
        self.console.pack(side="right", padx=20, pady=20)

    def log(self, msg):
        self.console.insert("end", f"{msg}\n")
        self.console.see("end")

    def start_test_thread(self):
        self.btn_run.configure(state="disabled")
        threading.Thread(target=self.run_verification_suite, daemon=True).start()

    def send_packet(self, ser, opcode, a, b):
        packet = bytes([int(opcode)]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
        ser.write(packet)
        time.sleep(0.01)

    def run_verification_suite(self):
        self.log("--- Starting 100-Test Validation ---")
        passed, failed = 0, 0
        
        try:
            ser = serial.Serial(self.port_menu.get(), 115200, timeout=1)
            ser.reset_input_buffer()
        except Exception as e:
            self.log(f"Connection Error: {e}")
            self.btn_run.configure(state="normal")
            return

        for i in range(1, 101):
            a = random.randint(0, 11)
            b = random.randint(0, 11)
            expected = a * b
            a_packed = a & 0xFF
            b_packed = b & 0xFF
            
            # --- THE LINE-BY-LINE VALIDATION ---
            self.send_packet(ser, 1, 0, 0)     # 1. Clear Memory
            self.send_packet(ser, 5, 8, 0)     # 2. Set Precision (INT8)
            self.send_packet(ser, 2, a_packed, b_packed) # 3. Do the Math
            self.send_packet(ser, 7, 0, 0)     # 4. Read Raw Result
            
            math_res = ser.read(1)
            if math_res:
                actual = int.from_bytes(math_res, 'big', signed=True)
                line = f"Test {i:03d}: A={a:3} | B={b:3} | Expected={expected:4} | Raw FPGA={actual:4}"
                
                if actual == expected:
                    self.log(f"[PASS] {line}")
                    passed += 1
                else:
                    self.log(f"[FAIL] {line} !!!")
                    failed += 1
            else:
                self.log(f"[FAIL] Test {i:03d}: Timeout")
                failed += 1
            
            time.sleep(0.05)
            
        self.log(f"--- Complete: {passed} Passed, {failed} Failed ---")
        ser.close()
        self.btn_run.configure(state="normal")

if __name__ == "__main__":
    app = SimplifiedValidationApp()
    app.mainloop()