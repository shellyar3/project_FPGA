import customtkinter as ctk
import serial
import threading
import random

# design settings
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class VerificationHostApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("MAC Core Verification Platform")
        self.geometry("1000x650")

        # screen layout
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # side bar for comunication settings
        self.sidebar = ctk.CTkFrame(self, width=220, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        
        self.lbl_title = ctk.CTkLabel(self.sidebar, text="UART Config", font=("Arial", 18, "bold"))
        self.lbl_title.pack(pady=20)

        self.port_menu = ctk.CTkOptionMenu(self.sidebar, values=["COM1", "COM2", "COM3", "COM4"])
        self.port_menu.pack(pady=10)

        self.btn_connect = ctk.CTkButton(self.sidebar, text="Connect to FPGA", command=self.connect_uart)
        self.btn_connect.pack(pady=10)

        # main - testing manage
        self.main_view = ctk.CTkFrame(self, corner_radius=15)
        self.main_view.grid(row=0, column=1, padx=20, pady=20, sticky="nsew")

        #operating buttons
        self.btn_run_suite = ctk.CTkButton(self.main_view, text="Run 500 Test Suite", 
                                          fg_color="green", command=self.start_test_thread)
        self.btn_run_suite.pack(pady=20)

        #statistical view in real time
        self.stats_frame = ctk.CTkFrame(self.main_view)
        self.stats_frame.pack(fill="x", padx=40, pady=10)
        
        self.passed_lbl = ctk.CTkLabel(self.stats_frame, text="Passed: 0", text_color="green")
        self.passed_lbl.pack(side="left", padx=20)
        
        self.failed_lbl = ctk.CTkLabel(self.stats_frame, text="Failed: 0", text_color="red")
        self.failed_lbl.pack(side="left", padx=20)

        #message log console
        self.console = ctk.CTkTextbox(self.main_view, width=700, height=300)
        self.console.pack(pady=20, padx=20)

    def connect_uart(self):
        self.log(f"Attempting to connect to {self.port_menu.get()}...")
        # opeaning of the serial to the board of DE10-Lite
        self.status_label = "Connected" 
        self.log("Status: FPGA Ready.")

    def log(self, msg):
        self.console.insert("end", f"> {msg}\n")
        self.console.see("end")

    def start_test_thread(self):
        #running the tests in the thread which is seperat of the GUI
        threading.Thread(target=self.run_verification_suite, daemon=True).start()

    def run_verification_suite(self):
        self.log("Starting Automated Test Suite")
        passed, failed = 0, 0
        # add running tests for verification
        
        

if __name__ == "__main__":
    app = VerificationHostApp()
    app.mainloop()