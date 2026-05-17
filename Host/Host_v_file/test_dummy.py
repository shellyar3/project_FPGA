import serial
import struct
import time

ser = serial.Serial('COM5', 115200, timeout=2)
time.sleep(1.5) # Wait for hardware reset stability

def test_dummy_pe(a, b, select=True, valid=True):
    # Control pattern: {chp_slct, valid_in, 3'b0, op_code[2:0]}
    ctrl_byte = (int(select) << 7) | (int(valid) << 6) | 0x00
    
    packet = struct.pack('>BII', ctrl_byte, a, b)
    ser.write(packet)
    ser.flush()
    
    status_byte = ser.read(1)
    data_byte = ser.read(1)
    
    if data_byte:
        print(f"Sent: A={a}, B={b} | CS Status={select}")
        print(f"Returned Output Byte: {ord(data_byte)}")
    else:
        print("Communication timeout. Check FPGA connection rails.")

print("--- RUNNING HARDWARE DUMMY STUB LOOPBACK ---")
# Test Case A: Active Chip Select (Should Add A + B)
test_dummy_pe(10, 5, select=True) # Expected: 15

# Test Case B: Gated Chip Select (Should ignore and return 0) 
test_dummy_pe(20, 30, select=False) # Expected: 0 or previous result
ser.close()