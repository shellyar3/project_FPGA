 🧠Reconfigurable, RISC-like Processing Element for Multi-Precision Neural Network Interface - FPGA team
 
Project Directory Structure
Simulation/

Contains the ModelSim simulation files, including all Processing Element (PE) files.

The testbench is written in SystemVerilog (.sv).

PE_Files/

Contains all source files provided directly by the PE team.

Host/

Verilog (.v) files: Includes the PE team files as well as a bridge module. This bridge interfaces the PE inputs/outputs with the computer's I/O and handles the conversion between serial and parallel data communication.

Python files: Contains the graphical user interface (GUI) and test execution scripts, supporting both automated and manual test runs.

Led_ctrl/

Contains early-stage learning and introductory files used to understand FPGA operation alongside basic Python control scripts.


How to Run on the FPGA
Connect the Hardware: Plug the FPGA board into your computer using the UART cable/connector.

Program the FPGA: Open Intel Quartus Prime, load the PE files and the bridge module, and flash (download) the design to the FPGA.

Run the Tests: Execute the Python script (or use the GUI) to communicate with the board and run your test sequences.
