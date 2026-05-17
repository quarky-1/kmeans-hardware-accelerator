// ============================================================================
// Module  : kmeans_top
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   Top-level integration of all K-Means accelerator submodules.
//   Instantiates and connects:
//     - fsm_controller       (control)
//     - distance_unit ×K     (compute dist from point to each centroid)
//     - min_comparator       (argmin across K distances)
//     - centroid_accumulator (sum points per cluster)
//     - centroid_updater     (divide sums by counts)
//     - convergence_check    (detect convergence)
//
// Parameters (all propagated from here):
//   K      = number of clusters
//   N      = number of data points (static for this version)
//   WIDTH  = fixed-point word width (Q8.8 = 16-bit)
//
// NOTE: Data loading interface is register-file based for this version.
//       A streaming AXI-S interface is planned for the FPGA target.
// ============================================================================

`timescale 1ns/1ps

module kmeans_top #(
    parameter K      = 4,
    parameter N      = 16,
    parameter WIDTH  = 16,
    parameter N_MAX  = 64,
    parameter ACC_W  = WIDTH + $clog2(N_MAX),
    parameter DIST_W = 2 * WIDTH
)(
    input  wire clk,
    input  wire rst_n,

    // Host control
    input  wire start,
    output wire done,

    // Input data: N points, 2D (x, y) in Q8.8
    // Flattened: point_data[i] = {point_y[i], point_x[i]}
    input  wire [N*2*WIDTH-1:0]   point_data,

    // Initial centroids (also serves as output after convergence)
    input  wire [K*WIDTH-1:0]     init_cent_x,
    input  wire [K*WIDTH-1:0]     init_cent_y,

    // Converged centroid outputs
    output wire [K*WIDTH-1:0]     out_cent_x,
    output wire [K*WIDTH-1:0]     out_cent_y,

    // Cluster assignment output (which centroid each point belongs to)
    output wire [N*$clog2(K)-1:0] assignments
);

    // ── Internal wires ────────────────────────────────────────────────────────

    // FSM control signals
    wire load_done, assign_done, update_done, converged;
    wire do_load, do_assign, do_update, do_check, clear_accum;

    // Current centroids (updated each iteration)
    reg  signed [WIDTH-1:0] cent_x [0:K-1];
    reg  signed [WIDTH-1:0] cent_y [0:K-1];

    // New centroids from updater
    wire signed [WIDTH-1:0] new_cent_x [0:K-1];
    wire signed [WIDTH-1:0] new_cent_y [0:K-1];

    // Per-point signals
    wire signed [WIDTH-1:0]          px [0:N-1];
    wire signed [WIDTH-1:0]          py [0:N-1];
    wire        [K*DIST_W-1:0]       dist_bus [0:N-1];
    wire        [$clog2(K)-1:0]      min_idx  [0:N-1];
    wire        [K-1:0]              clust_id [0:N-1];

    // Accumulator outputs
    wire signed [ACC_W-1:0]          sum_x [0:K-1];
    wire signed [ACC_W-1:0]          sum_y [0:K-1];
    wire        [$clog2(N_MAX):0]    count [0:K-1];

    // ── Unpack input data ─────────────────────────────────────────────────────
    genvar n;
    generate
        for (n = 0; n < N; n = n + 1) begin : unpack_points
            assign px[n] = point_data[(2*n+0)*WIDTH +: WIDTH];
            assign py[n] = point_data[(2*n+1)*WIDTH +: WIDTH];
        end
    endgenerate

    // ── FSM ───────────────────────────────────────────────────────────────────
    fsm_controller u_fsm (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .done        (done),
        .load_done   (load_done),
        .assign_done (assign_done),
        .update_done (update_done),
        .converged   (converged),
        .do_load     (do_load),
        .do_assign   (do_assign),
        .do_update   (do_update),
        .do_check    (do_check),
        .clear_accum (clear_accum)
    );

    // ── Distance units (one per centroid, instantiated per data point) ─────────
    // TODO: Time-multiplex over points rather than unrolling fully, to save area
    genvar k;
    generate
        for (n = 0; n < N; n = n + 1) begin : point_loop
            for (k = 0; k < K; k = k + 1) begin : centroid_loop
                distance_unit #(.INT_W(8), .FRAC_W(8)) u_dist (
                    .point_x (px[n]),
                    .point_y (py[n]),
                    .cent_x  (cent_x[k]),
                    .cent_y  (cent_y[k]),
                    .dist_sq (dist_bus[n][k*DIST_W +: DIST_W])
                );
            end

            min_comparator #(.K(K), .DIST_W(DIST_W)) u_min (
                .dist_in   (dist_bus[n]),
                .min_idx   (min_idx[n]),
                .cluster_id(clust_id[n])
            );

            assign assignments[n*$clog2(K) +: $clog2(K)] = min_idx[n];
        end
    endgenerate

    // ── Centroid accumulator ──────────────────────────────────────────────────
    // TODO: Serialize accumulation per point; currently accumulates point 0 only as placeholder
    centroid_accumulator #(.K(K), .WIDTH(WIDTH), .N_MAX(N_MAX)) u_accum (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear      (clear_accum),
        .accumulate (do_assign),
        .point_x    (px[0]),
        .point_y    (py[0]),
        .cluster_id (clust_id[0]),
        .sum_x      (sum_x),
        .sum_y      (sum_y),
        .count      (count)
    );

    // ── Centroid updater ──────────────────────────────────────────────────────
    centroid_updater #(.K(K), .WIDTH(WIDTH), .N_MAX(N_MAX)) u_updater (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (do_update),
        .done       (update_done),
        .sum_x      (sum_x),
        .sum_y      (sum_y),
        .count      (count),
        .new_cent_x (new_cent_x),
        .new_cent_y (new_cent_y)
    );

    // ── Convergence check ─────────────────────────────────────────────────────
    convergence_check #(.K(K), .WIDTH(WIDTH)) u_conv (
        .old_cent_x (cent_x),
        .old_cent_y (cent_y),
        .new_cent_x (new_cent_x),
        .new_cent_y (new_cent_y),
        .converged  (converged)
    );

    // ── Centroid register update ──────────────────────────────────────────────
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < K; i = i + 1) begin
                cent_x[i] <= init_cent_x[i*WIDTH +: WIDTH];
                cent_y[i] <= init_cent_y[i*WIDTH +: WIDTH];
            end
        end else if (update_done) begin
            for (i = 0; i < K; i = i + 1) begin
                cent_x[i] <= new_cent_x[i];
                cent_y[i] <= new_cent_y[i];
            end
        end
    end

    // ── Output centroid packing ───────────────────────────────────────────────
    generate
        for (k = 0; k < K; k = k + 1) begin : pack_out
            assign out_cent_x[k*WIDTH +: WIDTH] = cent_x[k];
            assign out_cent_y[k*WIDTH +: WIDTH] = cent_y[k];
        end
    endgenerate

endmodule
