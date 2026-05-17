import serial
import time

# Configuration - Ensure this matches your verified port
PORT = 'COM5'
BAUD_RATE = 115200

try:
    print(f"Opening connection on {PORT}...")
    # Increase timeout to 2 seconds to give hardware plenty of time to respond
    ser = serial.Serial(PORT, BAUD_RATE, timeout=2)
    
    # Crucial: Give the Windows driver a moment to initialize the physical lines
    time.sleep(1.5)
    
    # 1. Construct the 9-byte packet
    # Byte 0: Header config -> 0xC0 (chp_slct=1, valid_in=1, op_code=0)
    header = b'\xC0' 
    # Bytes 1-4: operand_A = 10 -> big-endian 32-bit: \x00\x00\x00\x0A
    operand_A = b'\x00\x00\x00\x0A'
    # Bytes 5-8: operand_B = 5  -> big-endian 32-bit: \x00\x00\x00\x05
    operand_B = b'\x00\x00\x00\x05'
    
    tx_packet = header + operand_A + operand_B
    
    print(f"Sending 9 bytes to FPGA: {tx_packet.hex().upper()}")
    ser.write(tx_packet)
    
    # Force Windows to push the bytes out of the PC RAM buffer down the USB wire
    ser.flush()
    
    print("Waiting for FPGA calculation...")
    # Give the state machine time to capture, process, and reply
    time.sleep(0.5)
    
    # 2. Read the 2-byte response back from the Bridge state machine
    # Byte 0: Status flag {busy, valid_out, 6'b0}
    # Byte 1: Calculation result (operand_A + operand_B)
    response = ser.read(2)
    
    print("-" * 40)
    if response == b'':
        print("Result: Received nothing (b'') - Timeout reached.")
    else:
        print(f"Raw Bytes Received (Hex): {response.hex().upper()}")
        if len(response) == 2:
            status_byte = response[0]
            data_byte = response[1]
            print(f"Status Byte Flag:  {bin(status_byte)}")
            print(f"Calculated Result: {data_byte} (Expected: 15)")
        else:
            print(f"Partial data received: {response}")
    print("-" * 40)

    ser.close()
    print("Port closed cleanly.")

except serial.SerialException as e:
    print(f"\n[SERIAL ERROR]: {e}")
    print("Check if PuTTY is still open or if the adapter was unplugged.")
except Exception as e:
    print(f"\n[ERROR]: {e}")