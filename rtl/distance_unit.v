// ============================================================================
// Module  : distance_unit
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Computes squared Euclidean distance between a data point and a centroid
//   in 2D fixed-point space (Q8.8).
//
//   dist² = (px - cx)² + (py - cy)²
//
//   Avoiding sqrt saves significant hardware resources — since we only need
//   to compare distances (not their absolute values), squared distance is
//   sufficient for argmin computation.
//
// Latency: Combinational (single-cycle)
// ============================================================================

`timescale 1ns/1ps

module distance_unit #(
    parameter INT_W  = 8,
    parameter FRAC_W = 8,
    parameter WIDTH  = INT_W + FRAC_W           // 16-bit Q8.8
)(
    // Data point coordinates
    input  wire signed [WIDTH-1:0] point_x,
    input  wire signed [WIDTH-1:0] point_y,

    // Centroid coordinates
    input  wire signed [WIDTH-1:0] cent_x,
    input  wire signed [WIDTH-1:0] cent_y,

    // Squared Euclidean distance output
    // Width is 2*WIDTH to safely hold the sum of two squared differences
    output wire signed [2*WIDTH-1:0] dist_sq
);

    // ── Difference terms ─────────────────────────────────────────────────────
    wire signed [WIDTH-1:0] diff_x;
    wire signed [WIDTH-1:0] diff_y;

    assign diff_x = point_x - cent_x;
    assign diff_y = point_y - cent_y;

    // ── Squared terms (via fixed_mult) ────────────────────────────────────────
    wire signed [WIDTH-1:0] sq_x;
    wire signed [WIDTH-1:0] sq_y;

    fixed_mult #(.INT_W(INT_W), .FRAC_W(FRAC_W)) u_sq_x (
        .a       (diff_x),
        .b       (diff_x),
        .product (sq_x)
    );

    fixed_mult #(.INT_W(INT_W), .FRAC_W(FRAC_W)) u_sq_y (
        .a       (diff_y),
        .b       (diff_y),
        .product (sq_y)
    );

    // ── Accumulate ────────────────────────────────────────────────────────────
    // Sign-extend to 2*WIDTH before adding to prevent overflow
    assign dist_sq = {{WIDTH{sq_x[WIDTH-1]}}, sq_x}
                   + {{WIDTH{sq_y[WIDTH-1]}}, sq_y};

endmodule
