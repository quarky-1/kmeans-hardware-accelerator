// ============================================================================
// Module  : centroid_accumulator
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   For each cluster, accumulates the sum of x and y coordinates of all
//   points assigned to it, and maintains a count of assigned points.
//
//   These running totals are consumed by centroid_updater to compute
//   new centroid positions: new_cx = sum_x / count.
//
//   Controlled by the FSM: cleared on LOAD→ASSIGN transition, accumulated
//   during ASSIGN, and read during UPDATE.
// ============================================================================

`timescale 1ns/1ps

module centroid_accumulator #(
    parameter K      = 4,
    parameter WIDTH  = 16,                          // Q8.8 data width
    parameter N_MAX  = 64,                          // max data points (sets counter width)
    parameter ACC_W  = WIDTH + $clog2(N_MAX)        // accumulator width to prevent overflow
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Control
    input  wire                       clear,         // from FSM: clear all accumulators
    input  wire                       accumulate,    // from FSM: latch current point

    // Data point being processed
    input  wire signed [WIDTH-1:0]    point_x,
    input  wire signed [WIDTH-1:0]    point_y,

    // Which cluster this point belongs to (one-hot, from min_comparator)
    input  wire [K-1:0]               cluster_id,

    // Accumulated outputs — one per cluster
    output reg  signed [ACC_W-1:0]    sum_x  [0:K-1],
    output reg  signed [ACC_W-1:0]    sum_y  [0:K-1],
    output reg  [$clog2(N_MAX):0]     count  [0:K-1]
);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            for (i = 0; i < K; i = i + 1) begin
                sum_x[i] <= 0;
                sum_y[i] <= 0;
                count[i] <= 0;
            end
        end else if (accumulate) begin
            for (i = 0; i < K; i = i + 1) begin
                if (cluster_id[i]) begin
                    sum_x[i] <= sum_x[i] + {{(ACC_W-WIDTH){point_x[WIDTH-1]}}, point_x};
                    sum_y[i] <= sum_y[i] + {{(ACC_W-WIDTH){point_y[WIDTH-1]}}, point_y};
                    count[i] <= count[i] + 1;
                end
            end
        end
    end

endmodule
