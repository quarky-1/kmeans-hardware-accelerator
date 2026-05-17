// ============================================================================
// Module  : centroid_updater
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Computes new centroid positions from accumulated sums and point counts.
//   new_cx[k] = sum_x[k] / count[k]  (fixed-point division)
//
//   Division is implemented as a right-arithmetic-shift approximation for
//   power-of-two counts, with a sequential divider for general case.
//
//   NOTE: Division is the only multi-cycle operation in the datapath.
//   The FSM waits for `update_done` before transitioning to CHECK_CONV.
//
// TODO: Implement sequential restoring divider or instantiate IP divider.
// ============================================================================

`timescale 1ns/1ps

module centroid_updater #(
    parameter K      = 4,
    parameter WIDTH  = 16,
    parameter N_MAX  = 64,
    parameter ACC_W  = WIDTH + $clog2(N_MAX)
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Control
    input  wire                       start,           // from FSM: begin update
    output reg                        done,            // to FSM: new centroids ready

    // Accumulator inputs
    input  wire signed [ACC_W-1:0]    sum_x  [0:K-1],
    input  wire signed [ACC_W-1:0]    sum_y  [0:K-1],
    input  wire [$clog2(N_MAX):0]     count  [0:K-1],

    // New centroid outputs
    output reg  signed [WIDTH-1:0]    new_cent_x [0:K-1],
    output reg  signed [WIDTH-1:0]    new_cent_y [0:K-1]
);

    integer i;

    // TODO: Replace with a proper sequential divider.
    // Current placeholder: combinational division (non-synthesizable for general N).
    // Will be replaced with a restoring divider (latency = WIDTH cycles per cluster).

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            for (i = 0; i < K; i = i + 1) begin
                new_cent_x[i] <= 0;
                new_cent_y[i] <= 0;
            end
        end else if (start) begin
            for (i = 0; i < K; i = i + 1) begin
                if (count[i] != 0) begin
                    // TODO: Replace with proper fixed-point division
                    new_cent_x[i] <= sum_x[i][ACC_W-1:ACC_W-WIDTH] / count[i];
                    new_cent_y[i] <= sum_y[i][ACC_W-1:ACC_W-WIDTH] / count[i];
                end
                // If count == 0, centroid stays unchanged (common convention)
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
