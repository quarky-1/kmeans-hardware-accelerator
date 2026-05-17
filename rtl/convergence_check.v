// ============================================================================
// Module  : convergence_check
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Compares old and new centroid positions across all K clusters.
//   Asserts `converged` if the maximum centroid shift across all clusters
//   falls below THRESHOLD (fixed-point, same Q8.8 format).
//
//   Using a threshold rather than strict equality makes the design robust
//   to fixed-point rounding that might otherwise prevent exact convergence.
// ============================================================================

`timescale 1ns/1ps

module convergence_check #(
    parameter K         = 4,
    parameter WIDTH     = 16,                    // Q8.8
    parameter THRESHOLD = 16'h0004               // 0.015625 in Q8.8 — tune as needed
)(
    input  wire signed [WIDTH-1:0] old_cent_x [0:K-1],
    input  wire signed [WIDTH-1:0] old_cent_y [0:K-1],
    input  wire signed [WIDTH-1:0] new_cent_x [0:K-1],
    input  wire signed [WIDTH-1:0] new_cent_y [0:K-1],

    output wire                    converged
);

    // Compute absolute shift per centroid and compare to threshold
    wire [WIDTH-1:0] shift_x [0:K-1];
    wire [WIDTH-1:0] shift_y [0:K-1];
    wire             within  [0:K-1];

    genvar k;
    generate
        for (k = 0; k < K; k = k + 1) begin : gen_check
            // Absolute difference
            assign shift_x[k] = (new_cent_x[k] >= old_cent_x[k])
                                  ? (new_cent_x[k] - old_cent_x[k])
                                  : (old_cent_x[k] - new_cent_x[k]);
            assign shift_y[k] = (new_cent_y[k] >= old_cent_y[k])
                                  ? (new_cent_y[k] - old_cent_y[k])
                                  : (old_cent_y[k] - new_cent_y[k]);

            assign within[k] = (shift_x[k] <= THRESHOLD) && (shift_y[k] <= THRESHOLD);
        end
    endgenerate

    // Converged only if ALL centroids are within threshold
    assign converged = &{within[0], within[1], within[2], within[3]};  // TODO: generalize for K

endmodule
