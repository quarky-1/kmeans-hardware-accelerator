// ============================================================================
// Module  : fixed_mult
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Parameterized fixed-point multiplier using Q(INT_W).(FRAC_W) format.
//   Performs A × B and returns the correctly truncated fixed-point product.
//   Both inputs and output share the same format: (INT_W + FRAC_W) bits wide.
//
//   Example with default Q8.8 (16-bit):
//     A = 0x0180  → 1.5 in Q8.8
//     B = 0x0200  → 2.0 in Q8.8
//     P = 0x0300  → 3.0 in Q8.8  (full product shifted right by FRAC_W)
// ============================================================================

`timescale 1ns/1ps

module fixed_mult #(
    parameter INT_W  = 8,                       // integer bits
    parameter FRAC_W = 8,                       // fractional bits
    parameter WIDTH  = INT_W + FRAC_W           // total word width = 16
)(
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] product
);

    // Full-precision intermediate: 2*WIDTH bits to avoid overflow before truncation
    wire signed [2*WIDTH-1:0] full_product;

    assign full_product = a * b;

    // Truncate: drop the lower FRAC_W fractional bits introduced by multiplication
    // and take the WIDTH bits above that
    assign product = full_product[WIDTH + FRAC_W - 1 : FRAC_W];

endmodule
