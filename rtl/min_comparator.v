// ============================================================================
// Module  : min_comparator
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Given K squared-distance values (one per centroid), finds the index of
//   the minimum — i.e., the nearest centroid for a given data point.
//
//   Implemented as a combinational priority tree for low latency.
//   K is parameterized; defaults to 4 clusters.
//
//   Output `cluster_id` is a one-hot encoded selection for easy downstream
//   accumulation control; `min_idx` gives the binary index.
// ============================================================================

`timescale 1ns/1ps

module min_comparator #(
    parameter K       = 4,              // number of clusters
    parameter DIST_W  = 32              // width of each distance input (2*WIDTH from distance_unit)
)(
    // K distance inputs, packed into one bus: [K*DIST_W-1:0]
    // dist_in[i] = dist_sq to centroid i, accessed as dist_in[i*DIST_W +: DIST_W]
    input  wire [K*DIST_W-1:0]   dist_in,

    output reg  [$clog2(K)-1:0]  min_idx,          // binary index of nearest centroid
    output reg  [K-1:0]          cluster_id         // one-hot: cluster_id[min_idx] = 1
);

    integer i;
    reg [DIST_W-1:0] min_val;
    reg [DIST_W-1:0] current;

    always @(*) begin
        // Initialise with centroid 0
        min_val    = dist_in[DIST_W-1:0];
        min_idx    = 0;
        cluster_id = {{(K-1){1'b0}}, 1'b1};        // one-hot: bit 0 set

        for (i = 1; i < K; i = i + 1) begin
            current = dist_in[i*DIST_W +: DIST_W];
            if (current < min_val) begin
                min_val    = current;
                min_idx    = i[$clog2(K)-1:0];
                cluster_id = (1 << i);
            end
        end
    end

endmodule
