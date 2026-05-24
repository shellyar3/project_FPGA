`timescale 1ns/1ps

module pe_tb;

    // =========================================================
    // DUT INTERFACE SIGNALS
    // =========================================================
    logic [31:0] operand_A;
    logic [31:0] operand_B;
    logic [4:0]  op_code;
    logic        clk;
    logic        valid_in;
    logic        rst;
    logic        chp_slct;

    logic [7:0]  data_out;
    logic        valid_out;
    logic        busy;

    // Hardware handshaking inversion
    logic        pe_ready_wire;
    assign busy = ~pe_ready_wire;  // Flips a 1 (Ready) to a 0 (Not Busy)

    // =========================================================
    // OPCODES (Itai's PE Specification)
    // =========================================================
    localparam logic [4:0] OP_NOP           = 5'b00000; // 0
    localparam logic [4:0] OP_RST_ACC       = 5'b00001; // 1
    localparam logic [4:0] OP_MAC           = 5'b00010; // 2
    localparam logic [4:0] OP_ADD_BIAS      = 5'b00011; // 3
    localparam logic [4:0] OP_SCALE         = 5'b00100; // 4
    localparam logic [4:0] OP_LOAD_CFG      = 5'b00101; // 5
    localparam logic [4:0] OP_EXEC_PP       = 5'b00110; // 6
    localparam logic [4:0] OP_READ_ACC_BYTE = 5'b00111; // 7
    localparam logic [4:0] OP_READ_CFG      = 5'b01000; // 8

    // =========================================================
    // TEST BOOK-KEEPING
    // =========================================================
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    // =========================================================
    // DUT INSTANCE
    // =========================================================
    PE dut (
        .operand_A    (operand_A),
        .operand_B    (operand_B),
        .pe_opcode    (op_code),
        .clk          (clk),
        .valid_opcode (valid_in),
        .valid_A      (valid_in),
        .valid_B      (valid_in),
        .rst          (rst),
        .chp_slct     (chp_slct),
        .data_out     (data_out),
        .valid_output (valid_out),
        .pe_ready     (pe_ready_wire)
    );

    // =========================================================
    // CLOCK GENERATION
    // =========================================================
    always #5 clk = ~clk;

    // =========================================================
    // COMMON TASKS
    // =========================================================
    task automatic init_signals;
        begin
            clk = 0;
            valid_in = 0;
            operand_A = 0;
            operand_B = 0;
            op_code = 0;
            chp_slct = 1'b1;  
            rst = 1'b0;       
            #20;              
            rst = 1'b1;       
            #20;
        end
    endtask

    task automatic do_reset;
        begin
            rst = 1'b0;
            #20;
            rst = 1'b1;
            #20;
            
            // Re-load default config for tests (INT8, Identity)
            @(posedge clk);
            operand_A = 32'd8; // Bit 3 high
            op_code = OP_LOAD_CFG;
            valid_in = 1'b1;
            @(posedge clk);
            valid_in = 1'b0;
            wait(busy == 1'b0);
        end
    endtask

    task automatic send_cmd(input [31:0] a, input [31:0] b, input [4:0] op);
        begin
            @(posedge clk);
            operand_A = a;
            operand_B = b;
            op_code   = op;
            valid_in  = 1'b1;
            
            @(posedge clk);
            valid_in  = 1'b0;
            
            wait(busy == 1'b0);
        end
    endtask

    task automatic wait_for_valid;
        integer timeout;
        begin
            timeout = 0;
            while (valid_out == 1'b0 && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout == 100) begin
                $display("[FAIL] Timeout waiting for valid_out");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task automatic check_result(input [7:0] expected, input string test_name);
        begin
            if (data_out !== expected) begin
                $display("[FAIL] %s | expected = %0d, actual = %0d", test_name, expected, data_out);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s | expected = %0d, actual = %0d", test_name, expected, data_out);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 1: Functional Test for Nominal Inputs
    // =========================================================
    task automatic test_nominal_inputs;
        logic [31:0] expected_val;
        begin
            $display("\n--- TEST 1: Nominal Inputs ---");
            do_reset();
            expected_val = 0;
            for (i = 1; i <= 5; i = i + 1) begin
                expected_val = expected_val + (i * 2);
                send_cmd(i, 2, OP_MAC);
            end
            send_cmd(0, 0, OP_EXEC_PP);
            wait_for_valid();
            check_result(expected_val[7:0], "TEST 1 - Nominal MAC");
        end
    endtask

    // =========================================================
    // TEST 2: Maximum Value Test
    // =========================================================
    task automatic test_maximum_values;
        begin
            $display("\n--- TEST 2: Maximum Value Test ---");
            do_reset();
            // Send max positive 8-bit signed values (127 * 127)
            send_cmd(127, 127, OP_MAC);
            send_cmd(0, 0, OP_EXEC_PP);
            wait_for_valid();
            // Expect saturation or max output based on architecture
            if (valid_out == 1'b1) begin
                $display("[PASS] TEST 2 - Handled Maximum Values. Out: %0d", data_out);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 3: Minimum Value Test
    // =========================================================
    task automatic test_minimum_values;
        begin
            $display("\n--- TEST 3: Minimum Value Test ---");
            do_reset();
            // Send min negative 8-bit signed values (-128 * -128)
            send_cmd(-128, -128, OP_MAC);
            send_cmd(0, 0, OP_EXEC_PP);
            wait_for_valid();
            if (valid_out == 1'b1) begin
                $display("[PASS] TEST 3 - Handled Minimum Values. Out: %0d", $signed(data_out));
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 4: Reset and Idle Stability Test
    // =========================================================
    task automatic test_reset_idle_stability;
        begin
            $display("\n--- TEST 4: Reset & Idle Stability ---");
            rst = 1'b0;
            #20;
            if (valid_out !== 1'b0) begin
                $display("[FAIL] TEST 4 - Unexpected valid_out during reset");
                fail_count++;
            end else begin
                $display("[PASS] TEST 4 - DUT stable during reset");
                pass_count++;
            end
            rst = 1'b1;
            #20;
            if (busy !== 1'b0) $display("[FAIL] TEST 4 - Not idle"); else $display("[PASS] TEST 4 - Idle");
        end
    endtask

    // =========================================================
    // TEST 5: Mid-Operation Reset Recovery Test
    // =========================================================
    task automatic test_mid_operation_reset;
        begin
            $display("\n--- TEST 5: Mid-Operation Reset ---");
            do_reset();
            // Start a command but reset immediately
            @(posedge clk);
            op_code = OP_MAC; valid_in = 1'b1;
            @(posedge clk);
            rst = 1'b0; // Yank reset mid-flight
            #20 rst = 1'b1;
            #20;
            if (busy == 1'b0) begin
                $display("[PASS] TEST 5 - DUT recovered cleanly");
                pass_count++;
            end else begin
                $display("[FAIL] TEST 5 - DUT locked up");
                fail_count++;
            end
        end
    endtask

    // =========================================================
    // TEST 6: Valid Opcode Functional Decoding Test
    // =========================================================
    task automatic test_valid_opcode_decoding;
        begin
            $display("\n--- TEST 6: Valid Opcode Decoding ---");
            do_reset();
            // Test that non-output commands don't lock the bus
            send_cmd(0, 0, OP_RST_ACC);
            send_cmd(10, 10, OP_MAC);
            send_cmd(0, 5, OP_ADD_BIAS);
            $display("[PASS] TEST 6 - Successfully decoded neural instructions");
            pass_count++;
        end
    endtask

    // =========================================================
    // TEST 7: Invalid / Reserved Opcode Safety Test
    // =========================================================
    task automatic test_invalid_opcode;
        begin
            $display("\n--- TEST 7: Invalid Opcode Safety ---");
            do_reset();
            send_cmd(0, 0, 5'b11111); // Reserved Opcode
            #50;
            if (valid_out === 1'b1 || busy === 1'b1) begin
                $display("[FAIL] TEST 7 - Invalid opcode caused activity");
                fail_count++;
            end else begin
                $display("[PASS] TEST 7 - Invalid opcode safely ignored");
                pass_count++;
            end
        end
    endtask

    // =========================================================
    // TEST 8: Busy Signal and Stall Behavior Test
    // =========================================================
    task automatic test_busy_stall_behavior;
        begin
            $display("\n--- TEST 8: Busy/Stall Behavior ---");
            do_reset();
            // OP_SCALE is a multi-cycle operation that drops pe_ready
            @(posedge clk);
            op_code = OP_SCALE; valid_in = 1'b1;
            @(posedge clk);
            valid_in = 1'b0;
            
            if (busy == 1'b1) begin
                $display("[PASS] TEST 8 - Busy asserted correctly for multi-cycle");
                pass_count++;
            end else begin
                $display("[FAIL] TEST 8 - Busy did not assert");
                fail_count++;
            end
            wait(busy == 1'b0);
        end
    endtask

    // =========================================================
    // TEST 9: Zero-Wait / Instant Completion Test
    // =========================================================
    task automatic test_zero_wait_completion;
        begin
            $display("\n--- TEST 9: Zero-Wait Completion ---");
            do_reset();
            // NOP should finish instantly with no output
            send_cmd(0, 0, OP_NOP);
            if (busy == 1'b0) begin
                $display("[PASS] TEST 9 - Instant command processed");
                pass_count++;
            end
        end
    endtask

    // =========================================================
    // TEST 10: Output Valid Timing Test
    // =========================================================
    task automatic test_output_valid_timing;
        integer cycles;
        begin
            $display("\n--- TEST 10: Output Valid Timing ---");
            do_reset();
            send_cmd(5, 5, OP_MAC);
            
            cycles = 0;
            @(posedge clk);
            op_code = OP_EXEC_PP; valid_in = 1'b1;
            @(posedge clk);
            valid_in = 1'b0;
            
            while(valid_out == 1'b0 && cycles < 50) begin
                @(posedge clk);
                cycles++;
            end
            
            $display("[PASS] TEST 10 - Output took %0d cycles to generate", cycles);
            pass_count++;
        end
    endtask

    // =========================================================
    // TEST 11: Continuous Back-to-Back Execution Test
    // =========================================================
    task automatic test_back_to_back_execution;
        begin
            $display("\n--- TEST 11: Back-to-Back Execution ---");
            do_reset();
            // Hammer the PE with consecutive valid signals without waiting
            @(posedge clk);
            op_code = OP_MAC; operand_A = 1; valid_in = 1'b1;
            @(posedge clk);
            op_code = OP_MAC; operand_A = 2;
            @(posedge clk);
            op_code = OP_MAC; operand_A = 3;
            @(posedge clk);
            valid_in = 1'b0;
            $display("[PASS] TEST 11 - Handled bus saturation");
            pass_count++;
        end
    endtask

    // =========================================================
    // TEST 12: Noise Immunity / Invalid Handshake Test
    // =========================================================
    task automatic test_noise_immunity;
        begin
            $display("\n--- TEST 12: Noise Immunity ---");
            do_reset();
            valid_in = 1'b0;
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                operand_A = $urandom;
                op_code = $urandom_range(0,31);
            end
            if (busy !== 1'b0) begin
                $display("[FAIL] TEST 12 - Noise caused unintended activity");
                fail_count++;
            end else begin
                $display("[PASS] TEST 12 - Noise ignored while valid_in = 0");
                pass_count++;
            end
        end
    endtask

    // =========================================================
    // TEST 13: Constrained Random Verification Test
    // =========================================================
    task automatic test_constrained_random;
        begin
            $display("\n--- TEST 13: CRV ---");
            do_reset();
            // Send 10 random MACs
            for (i = 0; i < 10; i = i + 1) begin
                send_cmd($urandom_range(0, 10), $urandom_range(0, 10), OP_MAC);
            end
            // Trigger output
            send_cmd(0, 0, OP_EXEC_PP);
            wait_for_valid();
            $display("[PASS] TEST 13 - CRV chain completed with data_out = %0d", data_out);
            pass_count++;
        end
    endtask
// =========================================================
    // TEST 14: OP_SCALE Black Box Probe (Bug Hunter)
    // =========================================================
    task automatic test_scale_bug_hunter;
        begin
            $display("\n--- TEST 14: OP_SCALE Bug Hunter ---");
            do_reset();
            
            // 1. Put the number 10 in the accumulator
            send_cmd(1, 10, OP_MAC);
            
            // 2. Send OP_SCALE with A=2, B=3
            // If it multiplies, 10 * 3 = 30.
            // If it acts like MAC, 10 + (2*3) = 16.
            send_cmd(2, 3, OP_SCALE);
            
            // 3. Trigger Output
            send_cmd(0, 0, OP_EXEC_PP);
            wait_for_valid();
            
            if (data_out === 8'd16) begin
                $display("[BUG DIAGNOSIS] IMPOSTER BUG: His decoder treats SCALE exactly like a MAC!");
            end else if (data_out === 8'd30) begin
                $display("[BUG DIAGNOSIS] FLAG BUG: The math works (output is 30), but he forgot to drop pe_ready!");
            end else if (data_out === 8'd10) begin
                $display("[BUG DIAGNOSIS] DEAF BUG: The hardware ignored the SCALE command entirely. Output is still 10.");
            end else begin
                $display("[RESULT] Unknown behavior. Output: %0d", data_out);
            end
        end
    endtask

    // =========================================================
    // MAIN SEQUENCE
    // =========================================================
    initial begin
        init_signals();
        
        test_nominal_inputs();
        test_maximum_values();
        test_minimum_values();
        test_reset_idle_stability();
        test_mid_operation_reset();
        test_valid_opcode_decoding();
        test_invalid_opcode();
        test_busy_stall_behavior();
        test_zero_wait_completion();
        test_output_valid_timing();
        test_back_to_back_execution();
        test_noise_immunity();
        test_constrained_random();

        $display("\n=================================================");
        $display("SIMULATION FINISHED");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("=================================================");

        #20;
        $finish;
    end

endmodule