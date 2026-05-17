// ============================================================================
// Testbench : tb_fixed_mult
// Project   : K-Means Clustering Hardware Accelerator
// ============================================================================
// Tests the fixed_mult module with known Q8.8 values.
// Self-checking: prints PASS/FAIL per test case.
//
// Run with:
//   iverilog -o sim/tb_fixed_mult tb/tb_fixed_mult.v rtl/fixed_mult.v
//   vvp sim/tb_fixed_mult
//   gtkwave sim/waveforms/tb_fixed_mult.vcd  (optional)
// ============================================================================

`timescale 1ns/1ps

module tb_fixed_mult;

    // Q8.8 format: value = bits / 256.0
    parameter INT_W  = 8;
    parameter FRAC_W = 8;
    parameter WIDTH  = INT_W + FRAC_W;  // 16

    reg  signed [WIDTH-1:0] a, b;
    wire signed [WIDTH-1:0] product;

    integer pass_count = 0;
    integer fail_count = 0;

    // DUT
    fixed_mult #(.INT_W(INT_W), .FRAC_W(FRAC_W)) uut (
        .a       (a),
        .b       (b),
        .product (product)
    );

    // Helper task: check result vs expected
    task check;
        input signed [WIDTH-1:0] got;
        input signed [WIDTH-1:0] expected;
        input [255:0] label;
        begin
            if (got === expected) begin
                $display("  PASS  %0s  →  %0d (0x%04h)", label, got, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %0s  →  got %0d (0x%04h), expected %0d (0x%04h)",
                          label, got, got, expected, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("sim/waveforms/tb_fixed_mult.vcd");
        $dumpvars(0, tb_fixed_mult);

        $display("=== fixed_mult testbench (Q8.8 fixed-point) ===\n");

        // Test 1: 1.0 × 1.0 = 1.0
        // Q8.8: 1.0 = 8'h01 << 8 = 16'h0100
        a = 16'h0100; b = 16'h0100; #10;
        check(product, 16'h0100, "1.0 x 1.0 = 1.0");

        // Test 2: 1.5 × 2.0 = 3.0
        // Q8.8: 1.5 = 0x0180, 2.0 = 0x0200, 3.0 = 0x0300
        a = 16'h0180; b = 16'h0200; #10;
        check(product, 16'h0300, "1.5 x 2.0 = 3.0");

        // Test 3: 2.5 × 2.5 = 6.25
        // Q8.8: 2.5 = 0x0280, 6.25 = 0x0640
        a = 16'h0280; b = 16'h0280; #10;
        check(product, 16'h0640, "2.5 x 2.5 = 6.25");

        // Test 4: 0.5 × 0.5 = 0.25
        // Q8.8: 0.5 = 0x0080, 0.25 = 0x0040
        a = 16'h0080; b = 16'h0080; #10;
        check(product, 16'h0040, "0.5 x 0.5 = 0.25");

        // Test 5: Negative × Positive: -1.0 × 2.0 = -2.0
        // Q8.8 signed: -1.0 = 0xFF00, -2.0 = 0xFE00
        a = 16'hFF00; b = 16'h0200; #10;
        check(product, 16'hFE00, "-1.0 x 2.0 = -2.0");

        // Test 6: 0 × anything = 0
        a = 16'h0000; b = 16'h0280; #10;
        check(product, 16'h0000, "0.0 x 2.5 = 0.0");

        $display("\n=== Results: %0d passed, %0d failed ===\n", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED — check above");

        $finish;
    end

endmodule
