
#first version
import serial
import struct

ser = serial.Serial('COM3', 115200, timeout=2) # Adjust COM port

def run_pe_test(val_a, val_b):
    # Pack integers into 4-byte big-endian format
    data_to_send = struct.pack('>II', val_a, val_b)
    ser.write(data_to_send)
    
    # Wait for 4-byte result
    response = ser.read(4)
    if len(response) == 4:
        result = struct.unpack('>I', response)[0]
        return result
    return None

# Example Test
a, b = 1000, 2000
res = run_pe_test(a, b)
print(f"PE Output for {a} and {b}: {res}")