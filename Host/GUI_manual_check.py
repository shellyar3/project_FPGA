import customtkinter as ctk
import serial
import time

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class ManualDebuggerApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Neural PE - Manual Debugger")
        self.geometry("600x500")

        #  Port Connection 
        self.port_frame = ctk.CTkFrame(self)
        self.port_frame.pack(pady=10, padx=20, fill="x")
        self.lbl_port = ctk.CTkLabel(self.port_frame, text="COM Port:")
        self.lbl_port.pack(side="left", padx=10)
        self.port_entry = ctk.CTkEntry(self.port_frame, width=100)
        self.port_entry.insert(0, "COM5")
        self.port_entry.pack(side="left", padx=10)

        # Raw Packet Sender 
        self.raw_frame = ctk.CTkFrame(self)
        self.raw_frame.pack(pady=10, padx=20, fill="x")
        ctk.CTkLabel(self.raw_frame, text="1. Send Raw Instruction", font=("Arial", 16, "bold")).grid(row=0, column=0, columnspan=4, pady=10)
        
        ctk.CTkLabel(self.raw_frame, text="Opcode:").grid(row=1, column=0, padx=5)
        self.entry_op = ctk.CTkEntry(self.raw_frame, width=60)
        self.entry_op.grid(row=1, column=1, padx=5)
        self.entry_op.insert(0, "8") # Default to READ_CFG

        ctk.CTkLabel(self.raw_frame, text="Operand A:").grid(row=1, column=2, padx=5)
        self.entry_a = ctk.CTkEntry(self.raw_frame, width=80)
        self.entry_a.grid(row=1, column=3, padx=5)
        self.entry_a.insert(0, "0")

        ctk.CTkLabel(self.raw_frame, text="Operand B:").grid(row=1, column=4, padx=5)
        self.entry_b = ctk.CTkEntry(self.raw_frame, width=80)
        self.entry_b.grid(row=1, column=5, padx=5)
        self.entry_b.insert(0, "0")

        self.btn_send_raw = ctk.CTkButton(self.raw_frame, text="Send Raw", command=self.send_raw)
        self.btn_send_raw.grid(row=2, column=0, columnspan=6, pady=15)

        # Safe Pipeline Sender 
        self.pipe_frame = ctk.CTkFrame(self)
        self.pipe_frame.pack(pady=10, padx=20, fill="x")
        ctk.CTkLabel(self.pipe_frame, text="2. Run Safe Math Pipeline (RST->CFG->MAC->READ)", font=("Arial", 16, "bold")).grid(row=0, column=0, columnspan=4, pady=10)
        
        ctk.CTkLabel(self.pipe_frame, text="Value A:").grid(row=1, column=0, padx=5)
        self.pipe_a = ctk.CTkEntry(self.pipe_frame, width=80)
        self.pipe_a.grid(row=1, column=1, padx=5)

        ctk.CTkLabel(self.pipe_frame, text="Value B:").grid(row=1, column=2, padx=5)
        self.pipe_b = ctk.CTkEntry(self.pipe_frame, width=80)
        self.pipe_b.grid(row=1, column=3, padx=5)

        self.btn_send_pipe = ctk.CTkButton(self.pipe_frame, text="Execute Math Pipeline", fg_color="green", command=self.send_pipeline)
        self.btn_send_pipe.grid(row=2, column=0, columnspan=4, pady=15)

        # Output Display 
        self.out_frame = ctk.CTkFrame(self)
        self.out_frame.pack(pady=10, padx=20, fill="both", expand=True)
        self.lbl_out = ctk.CTkLabel(self.out_frame, text="Hardware Output: ---", font=("Consolas", 24, "bold"), text_color="yellow")
        self.lbl_out.pack(pady=30)

    def _transmit(self, opcode, a, b, read_bytes=0):
        """Internal function to handle serial comms safely"""
        port = self.port_entry.get()
        try:
            with serial.Serial(port, 115200, timeout=1) as ser:
                packet = bytes([int(opcode)]) + int(a).to_bytes(4, 'big', signed=True) + int(b).to_bytes(4, 'big', signed=True)
                ser.write(packet)
                time.sleep(0.05)
                
                if read_bytes > 0:
                    res = ser.read(read_bytes)
                    if res:
                        return int.from_bytes(res, 'big', signed=True)
                    return "Timeout (No Data)"
                return None
        except Exception as e:
            return f"Error: {e}"

    def send_raw(self):
        op = self.entry_op.get()
        a = self.entry_a.get()
        b = self.entry_b.get()
        
        # Only read a response if it's an output command (6, 7, or 8)
        reads = 1 if op in ["6", "7", "8"] else 0
        
        result = self._transmit(op, a, b, read_bytes=reads)
        if reads == 0:
            self.lbl_out.configure(text=f"Command {op} Sent (No output expected)")
        else:
            self.lbl_out.configure(text=f"Raw Output: {result}")

    def send_pipeline(self):
        try:
            a = int(self.pipe_a.get())
            b = int(self.pipe_b.get())
        except ValueError:
            self.lbl_out.configure(text="Please enter valid integers.")
            return

        # 1. Reset Accumulator (Opcode 1)
        self._transmit(1, 0, 0)
        
        # 2. LOAD_CFG (Opcode 5): Switch to INT8 mode & Identity Activation
        # Bit 3 = 1 (INT8), Bits [2:0] = 000 (Identity). Binary 1000 = Decimal 8.
        self._transmit(5, 8, 0)
        
        # 3. MAC (Opcode 2): Perform the math
        self._transmit(2, a, b)
        
        # 4. SCALE (Opcode 4): Shift = 0 (Operand A), Scale = 1 (Operand B)
        self._transmit(4, 0, 1)
        
        # 5. EXEC_PP (Opcode 6): Post-process and read the 1-byte output
        result = self._transmit(6, 0, 0, read_bytes=1)
        
        self.lbl_out.configure(text=f"Math Result: {result}")
        
        

if __name__ == "__main__":
    app = ManualDebuggerApp()
    app.mainloop()