import serial
import time

# Change this to your serial port
# Examples:
# Windows: "COM3"

PORT = "COM3"
BAUDRATE = 115200

def main():
    ser = serial.Serial(PORT, BAUDRATE, timeout=1)
    time.sleep(2)  # give port time to settle

    print(f"Connected to {PORT} at {BAUDRATE} baud")
    print("Type 1 to turn LED on, 0 to turn LED off, q to quit")

    try:
        while True:
            cmd = input("Enter command: ").strip()

            if cmd.lower() == "q":
                break

            if cmd not in ("0", "1"):
                print("Please enter only 0, 1, or q")
                continue

            # send ASCII '0' or '1'
            ser.write(cmd.encode("ascii"))

            # optional: read echoed byte back from FPGA
            resp = ser.read(1)
            if resp:
                try:
                    print("FPGA echo:", resp.decode("ascii"))
                except UnicodeDecodeError:
                    print("FPGA echo (raw):", resp)

    finally:
        ser.close()
        print("Serial port closed")

if __name__ == "__main__":
    main()