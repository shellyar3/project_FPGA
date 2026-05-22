`timescale 1ns/1ps

module pe_tb;

    // =========================================================
    // DUT INTERFACE SIGNALS
    // Change widths/names here if your PE is slightly different
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

    // =========================================================
    // LOCALPARAMS
    // Replace these opcode values with your real PE opcodes
    // =========================================================
    localparam logic [4:0] OP_NOP  = 5'd0;
    localparam logic [4:0] OP_MAC  = 5'd1;
    localparam logic [4:0] OP_ADD  = 5'd2;
    localparam logic [4:0] OP_SUB  = 5'd3;
    localparam logic [4:0] OP_MUL  = 5'd4;
    localparam logic [4:0] OP_FAST = 5'd5;

    // =========================================================
    // TESTBOOK-KEEPING
    // =========================================================
    integer pass_count = 0;
    integer fail_count = 0;

    integer i;
    integer threshold;
    integer expected_mac;
    logic   expected_binary;

    logic [31:0] pixel_array  [0:63];
    logic [31:0] weight_array [0:63];

    // =========================================================
    // DUT INSTANCE
    // IMPORTANT:
    // Replace "PE" with your real module name if different
    // =========================================================
    PE dut (
        .operand_A (operand_A),
        .operand_B (operand_B),
        .op_code   (op_code),
        .clk       (clk),
        .valid_in  (valid_in),
        .rst       (rst),
        .chp_slct  (chp_slct),
        .data_out  (data_out),
        .valid_out (valid_out),
        .busy      (busy)
    );

    // =========================================================
    // CLOCK GENERATION
    // 10ns period = 100 MHz
    // =========================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================
    // REFERENCE MODEL HELPERS
    // =========================================================
    function automatic integer calc_expected_mac;
        integer j;
        integer sum;
        begin
            sum = 0;
            for (j = 0; j < 64; j = j + 1) begin
                sum = sum + (pixel_array[j] * weight_array[j]);
            end
            calc_expected_mac = sum;
        end
    endfunction

    function automatic [7:0] ref_add(
        input logic [31:0] a,
        input logic [31:0] b
    );
        begin
            ref_add = (a + b) & 8'hFF;
        end
    endfunction

    function automatic [7:0] ref_sub(
        input logic [31:0] a,
        input logic [31:0] b
    );
        begin
            ref_sub = (a - b) & 8'hFF;
        end
    endfunction

    function automatic [7:0] ref_mul(
        input logic [31:0] a,
        input logic [31:0] b
    );
        begin
            ref_mul = (a * b) & 8'hFF;
        end
    endfunction

    // =========================================================
    // COMMON TASKS
    // =========================================================
    task automatic init_signals;
        begin
            operand_A = 32'd0;
            operand_B = 32'd0;
            op_code   = OP_NOP;
            valid_in  = 1'b0;
            rst       = 1'b0;
            chp_slct  = 1'b0;
        end
    endtask

    task automatic do_reset;
        begin
            operand_A = 32'd0;
            operand_B = 32'd0;
            op_code   = OP_NOP;
            valid_in  = 1'b0;
            chp_slct  = 1'b0;

            rst = 1'b1;
            repeat (5) @(posedge clk);
            rst = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic send_cmd(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [4:0]  opcode
    );
        begin
            @(posedge clk);
            operand_A <= a;
            operand_B <= b;
            op_code   <= opcode;
            valid_in  <= 1'b1;

            @(posedge clk);
            valid_in  <= 1'b0;
        end
    endtask

    task automatic wait_for_valid;
        integer timeout_count;
        begin
            timeout_count = 0;
            while ((valid_out !== 1'b1) && (timeout_count < 200)) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 200) begin
                $display("[FAIL] Timeout waiting for valid_out");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task automatic check_result(
        input logic [7:0] expected,
        input string test_name
    );
        begin
            if (data_out !== expected) begin
                $display("[FAIL] %s | expected = %0d, actual = %0d", test_name, expected, data_out);
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] %s | expected = %0d, actual = %0d", test_name, expected, data_out);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task automatic check_no_valid(
        input string test_name
    );
        begin
            if (valid_out === 1'b1) begin
                $display("[FAIL] %s | valid_out asserted unexpectedly", test_name);
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] %s | valid_out stayed low as expected", test_name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 1: Functional Test for Nominal Inputs
    // =========================================================
    task automatic test_nominal_inputs;
        begin
            $display("\n=================================================");
            $display("TEST 1 - Functional Test for Nominal Inputs");
            $display("=================================================");

            do_reset();

            for (i = 0; i < 64; i = i + 1) begin
                pixel_array[i]  = i + 1;
                weight_array[i] = 2;
            end

            threshold       = 1000;
            expected_mac    = calc_expected_mac();
            expected_binary = (expected_mac >= threshold);

            for (i = 0; i < 64; i = i + 1) begin
                send_cmd(pixel_array[i], weight_array[i], OP_MAC);
            end

            wait_for_valid();
            check_result({7'd0, expected_binary}, "TEST 1 - Nominal MAC");
        end
    endtask

    // =========================================================
    // TEST 2: Maximum Value Test
    // =========================================================
    task automatic test_maximum_values;
        begin
            $display("\n=================================================");
            $display("TEST 2 - Maximum Value Test");
            $display("=================================================");

            do_reset();

            for (i = 0; i < 64; i = i + 1) begin
                pixel_array[i]  = 32'd255;
                weight_array[i] = 32'd255;
            end

            threshold       = 32'h7fffffff;
            expected_mac    = calc_expected_mac();
            expected_binary = (expected_mac >= threshold);

            for (i = 0; i < 64; i = i + 1) begin
                send_cmd(pixel_array[i], weight_array[i], OP_MAC);
            end

            wait_for_valid();
            check_result({7'd0, expected_binary}, "TEST 2 - Maximum Values");
        end
    endtask

    // =========================================================
    // TEST 3: Minimum Value Test
    // =========================================================
    task automatic test_minimum_values;
        begin
            $display("\n=================================================");
            $display("TEST 3 - Minimum Value Test");
            $display("=================================================");

            do_reset();

            for (i = 0; i < 64; i = i + 1) begin
                pixel_array[i]  = 32'd0;
                weight_array[i] = 32'd0;
            end

            threshold       = 0;
            expected_mac    = calc_expected_mac();
            expected_binary = (expected_mac >= threshold);

            for (i = 0; i < 64; i = i + 1) begin
                send_cmd(pixel_array[i], weight_array[i], OP_MAC);
            end

            wait_for_valid();
            check_result({7'd0, expected_binary}, "TEST 3 - Minimum Values");
        end
    endtask

    // =========================================================
    // TEST 4: Reset and Idle Stability Test
    // =========================================================
    task automatic test_reset_idle_stability;
        begin
            $display("\n=================================================");
            $display("TEST 4 - Reset and Idle Stability Test");
            $display("=================================================");

            init_signals();

            rst = 1'b1;
            repeat (4) @(posedge clk);

            if ((busy !== 1'b0) || (valid_out !== 1'b0)) begin
                $display("[FAIL] TEST 4 - Unexpected busy/valid_out during reset");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 4 - DUT stable during reset");
                pass_count = pass_count + 1;
            end

            rst = 1'b0;
            repeat (5) @(posedge clk);

            if ((busy !== 1'b0) || (valid_out !== 1'b0)) begin
                $display("[FAIL] TEST 4 - DUT not idle after reset release");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 4 - DUT idle after reset release");
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 5: Mid-Operation Reset Recovery Test
    // =========================================================
    task automatic test_mid_operation_reset;
        begin
            $display("\n=================================================");
            $display("TEST 5 - Mid-Operation Reset Recovery Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd20, 32'd3, OP_MUL);

            wait (busy == 1'b1);
            @(posedge clk);
            rst <= 1'b1;
            @(posedge clk);
            rst <= 1'b0;

            repeat (5) @(posedge clk);

            if ((busy !== 1'b0) || (valid_out !== 1'b0)) begin
                $display("[FAIL] TEST 5 - DUT did not recover cleanly after mid-operation reset");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 5 - DUT recovered cleanly after mid-operation reset");
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 6: Valid Opcode Functional Decoding Test
    // =========================================================
    task automatic test_valid_opcode_decoding;
        begin
            $display("\n=================================================");
            $display("TEST 6 - Valid Opcode Functional Decoding Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd10, 32'd5, OP_ADD);
            wait_for_valid();
            check_result(ref_add(32'd10, 32'd5), "TEST 6 - ADD");

            send_cmd(32'd10, 32'd5, OP_SUB);
            wait_for_valid();
            check_result(ref_sub(32'd10, 32'd5), "TEST 6 - SUB");

            send_cmd(32'd4, 32'd3, OP_MUL);
            wait_for_valid();
            check_result(ref_mul(32'd4, 32'd3), "TEST 6 - MUL");
        end
    endtask

    // =========================================================
    // TEST 7: Invalid / Reserved Opcode Safety Test
    // =========================================================
    task automatic test_invalid_opcode;
        begin
            $display("\n=================================================");
            $display("TEST 7 - Invalid / Reserved Opcode Safety Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd10, 32'd20, 5'd31);
            repeat (10) @(posedge clk);

            check_no_valid("TEST 7 - Invalid Opcode");
        end
    endtask

    // =========================================================
    // TEST 8: Busy Signal and Stall Behavior Test
    // =========================================================
    task automatic test_busy_stall_behavior;
        begin
            $display("\n=================================================");
            $display("TEST 8 - Busy Signal and Stall Behavior Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd20, 32'd10, OP_MUL);
            wait (busy == 1'b1);

            // Try to overlap another command while DUT is busy
            send_cmd(32'd1, 32'd1, OP_ADD);

            wait_for_valid();

            if (busy !== 1'b0) begin
                $display("[FAIL] TEST 8 - busy did not deassert after completion");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 8 - busy asserted/deasserted correctly");
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 9: Zero-Wait / Instant Completion Test
    // =========================================================
    task automatic test_zero_wait_completion;
        begin
            $display("\n=================================================");
            $display("TEST 9 - Zero-Wait / Instant Completion Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd7, 32'd8, OP_FAST);
            wait_for_valid();
            check_result(8'd15, "TEST 9 - Fast Operation");
        end
    endtask

    // =========================================================
    // TEST 10: Output Valid Timing Test
    // =========================================================
    task automatic test_output_valid_timing;
        integer cycle_count;
        begin
            $display("\n=================================================");
            $display("TEST 10 - Output Valid Timing Test");
            $display("=================================================");

            do_reset();

            cycle_count = 0;

            @(posedge clk);
            operand_A <= 32'd9;
            operand_B <= 32'd2;
            op_code   <= OP_MUL;
            valid_in  <= 1'b1;

            @(posedge clk);
            valid_in <= 1'b0;

            while (valid_out !== 1'b1 && cycle_count < 100) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end

            if (valid_out !== 1'b1) begin
                $display("[FAIL] TEST 10 - valid_out never asserted");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 10 - valid_out asserted after %0d cycles", cycle_count);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 11: Continuous Back-to-Back Execution Test
    // =========================================================
    task automatic test_back_to_back_execution;
        begin
            $display("\n=================================================");
            $display("TEST 11 - Continuous Back-to-Back Execution Test");
            $display("=================================================");

            do_reset();

            send_cmd(32'd2, 32'd3, OP_ADD);
            wait_for_valid();
            check_result(ref_add(32'd2, 32'd3), "TEST 11 - ADD");

            send_cmd(32'd8, 32'd2, OP_SUB);
            wait_for_valid();
            check_result(ref_sub(32'd8, 32'd2), "TEST 11 - SUB");

            send_cmd(32'd3, 32'd4, OP_MUL);
            wait_for_valid();
            check_result(ref_mul(32'd3, 32'd4), "TEST 11 - MUL");
        end
    endtask

    // =========================================================
    // TEST 12: Noise Immunity / Invalid Handshake Test
    // =========================================================
    task automatic test_noise_immunity;
        begin
            $display("\n=================================================");
            $display("TEST 12 - Noise Immunity / Invalid Handshake Test");
            $display("=================================================");

            do_reset();

            valid_in = 1'b0;

            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                operand_A <= $urandom;
                operand_B <= $urandom;
                op_code   <= $urandom_range(0, 31);
            end

            if ((busy !== 1'b0) || (valid_out !== 1'b0)) begin
                $display("[FAIL] TEST 12 - Noise caused unintended activity");
                fail_count = fail_count + 1;
            end
            else begin
                $display("[PASS] TEST 12 - Noise ignored while valid_in = 0");
                pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================
    // TEST 13: Constrained Random Verification Test
    // =========================================================
    task automatic test_constrained_random;
        logic [31:0] rand_a;
        logic [31:0] rand_b;
        logic [4:0]  rand_op;
        logic [7:0]  expected;
        begin
            $display("\n=================================================");
            $display("TEST 13 - Constrained Random Verification Test");
            $display("=================================================");

            do_reset();

            for (i = 0; i < 30; i = i + 1) begin
                rand_a = $urandom_range(0, 255);
                rand_b = $urandom_range(0, 255);
                rand_op = $urandom_range(2, 4); // ADD/SUB/MUL in this template

                send_cmd(rand_a, rand_b, rand_op);
                wait_for_valid();

                case (rand_op)
                    OP_ADD: expected = ref_add(rand_a, rand_b);
                    OP_SUB: expected = ref_sub(rand_a, rand_b);
                    OP_MUL: expected = ref_mul(rand_a, rand_b);
                    default: expected = 8'd0;
                endcase

                check_result(expected, "TEST 13 - CRV Transaction");
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