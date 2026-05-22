import serial
import time
import customtkinter as ctk

# Configure modern dark UI theme styles
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class FPGAControlApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("FPGA NN Processing Element Verification Hub")
        self.geometry("600(w) x 620(h)")
        self.geometry("600x620")
        self.resizable(False, False)

        # Communication Constants - Adjust if your virtual port updates
        self.PORT = 'COM5'
        self.BAUD_RATE = 115200
        self.ser = None

        # Dictionary mapping human-readable names to their 5-bit integer opcodes
        self.OPCODE_MAP = {
            "00: ADD (Addition)": 0,
            "01: SUB (Subtraction)": 1,
            "02: MUL (Multiplication)": 2,
            "03: AND (Bitwise AND)": 3,
            "04: OR  (Bitwise OR)": 4,
            "05: MAC (Multiply-Accumulate)": 5
        }

        # --- UI ELEMENTS LAYOUT ---
        
        # Main Window Header
        self.title_label = ctk.CTkLabel(self, text="Hardware-In-The-Loop Verification", font=ctk.CTkFont(size=22, weight="bold"))
        self.title_label.pack(pady=20)

        # Configuration Parameter Container
        self.input_frame = ctk.CTkFrame(self)
        self.input_frame.pack(pady=10, padx=20, fill="x")

        # Operand A Input Entry Layout
        self.label_A = ctk.CTkLabel(self.input_frame, text="Operand A (32-bit Integer Input):", font=ctk.CTkFont(size=14))
        self.label_A.grid(row=0, column=0, padx=20, pady=12, sticky="w")
        self.entry_A = ctk.CTkEntry(self.input_frame, width=160)
        self.entry_A.grid(row=0, column=1, padx=20, pady=12)
        self.entry_A.insert(0, "45")

        # Operand B Input Entry Layout
        self.label_B = ctk.CTkLabel(self.input_frame, text="Operand B (32-bit Integer Input):", font=ctk.CTkFont(size=14))
        self.label_B.grid(row=1, column=0, padx=20, pady=12, sticky="w")
        self.entry_B = ctk.CTkEntry(self.input_frame, width=160)
        self.entry_B.grid(row=1, column=1, padx=20, pady=12)
        self.entry_B.insert(0, "15")

        # Opcode Dropdown Menu Selection Layout
        self.label_Op = ctk.CTkLabel(self.input_frame, text="Select PE Operation (5-bit Opcode):", font=ctk.CTkFont(size=14))
        self.label_Op.grid(row=2, column=0, padx=20, pady=12, sticky="w")
        self.combobox_Op = ctk.CTkComboBox(self.input_frame, values=list(self.OPCODE_MAP.keys()), width=160)
        self.combobox_Op.grid(row=2, column=1, padx=20, pady=12)
        self.combobox_Op.set("00: ADD (Addition)") # Set default mode baseline

        # Main Dynamic Core Execution Trigger Button
        self.run_btn = ctk.CTkButton(self, text="Execute Hardware Calculation", command=self.send_to_fpga, font=ctk.CTkFont(size=15, weight="bold"), height=42)
        self.run_btn.pack(pady=15)

        # Diagnostics Output Terminal Box Container
        self.output_frame = ctk.CTkFrame(self, fg_color="#111111")
        self.output_frame.pack(pady=10, padx=20, fill="both", expand=True)

        self.console_log = ctk.CTkTextbox(self.output_frame, font=ctk.CTkFont(family="Consolas", size=12), text_color="#00FF00", fg_color="#111111")
        self.console_log.pack(padx=10, pady=10, fill="both", expand=True)
        
        self.log_message("System Initialization Ready.")
        self.log_message("Please ensure DE10-Lite is powered, flashed, and KEY[0] has been cycled.")

    def log_message(self, message):
        """Appends formatted terminal tracking status updates into the scrolling UI log"""
        self.console_log.insert("end", message + "\n")
        self.console_log.see("end")

    def send_to_fpga(self):
        # Disable button during transaction pipeline to eliminate line spamming
        self.run_btn.configure(state="disabled")
        
        try:
            # 1. Gather raw textual configurations from text fields
            val_A = int(self.entry_A.get())
            val_B = int(self.entry_B.get())
            selected_op_text = self.combobox_Op.get()
            
            # Map selected textual operation string to its corresponding 5-bit value
            opcode_val = self.OPCODE_MAP[selected_op_text]

            # 2. Compute the 8-bit configurations header mask byte
            # Force Bit 7 and Bit 6 high for Chip-Select and Valid In (11xxxxxx)
            # Mask lower 5 bits directly with our targeted opcode execution parameter
            header_value = 0xC0 | (opcode_val & 0x1F)
            header = bytes([header_value])

            # Convert large integers into big-endian byte sequences
            op_A_bytes = val_A.to_bytes(4, byteorder='big')
            op_B_bytes = val_B.to_bytes(4, byteorder='big')
            tx_packet = header + op_A_bytes + op_B_bytes

            self.log_message(f"\n[INIT]: Opening serial communication channel on {self.PORT}...")
            self.ser = serial.Serial(self.PORT, self.BAUD_RATE, timeout=1.5)
            time.sleep(0.05) # Settle line latency buffers

            # 3. Stream data frames across the physical driver pipeline
            self.log_message(f"[TX]: Masked Header: 0x{header.hex().upper()} (Opcode {opcode_val} -> {selected_op_text.split(':')[1].strip()})")
            self.log_message(f"[TX]: Complete 9-Byte Transaction Cluster: {tx_packet.hex().upper()}")
            
            self.ser.reset_input_buffer()
            self.ser.write(tx_packet)
            self.ser.flush()

            # 4. Wait for processing response frame
            time.sleep(0.05)
            response = self.ser.read(2)

            # 5. Extract and print parsed evaluation results
            if len(response) == 2:
                status_byte = response[0]
                calculated_result = response[1]
                
                self.log_message(f"[RX]: Raw Hardware Hex Returned: {response.hex().upper()}")
                self.log_message(f"[STATUS]: Handshake Byte Array Profile = {bin(status_byte)}")
                self.log_message(f"[SUCCESS]: Core PE Evaluated Result = {calculated_result}")
            else:
                self.log_message("[TIMEOUT ERROR]: No response returned from FPGA. Check wiring path or hit KEY[0].")

            self.ser.close()

        except ValueError:
            self.log_message("[INPUT ERROR]: Please provide clean, numeric base integers in the input entries.")
        except serial.SerialException as e:
            self.log_message(f"[SERIAL ERROR]: Port connection failure encountered: {e}")
        except Exception as e:
            self.log_message(f"[ERROR]: An unexpected handling error occurred: {e}")
            if self.ser and self.ser.is_open:
                self.ser.close()
                
        # Return operational control state to the click button handle
        self.run_btn.configure(state="normal")

if __name__ == "__main__":
    app = FPGAControlApp()
    app.mainloop()