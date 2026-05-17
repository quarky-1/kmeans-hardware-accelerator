// ============================================================================
// Module  : fsm_controller
// Project : K-Means Clustering Hardware Accelerator
// Author  : Sarthak Tripathi
// ============================================================================
// Description:
//   5-state Moore FSM that sequences the K-Means algorithm across the
//   hardware datapath.
//
//   State encoding:
//     IDLE       : Wait for start signal
//     LOAD       : Load data points and initial centroids from input registers
//     ASSIGN     : For each point, compute distances and assign to nearest centroid
//     UPDATE     : Compute new centroid positions from accumulated sums
//     CHECK_CONV : Compare old vs new centroids; loop or assert done
//
//   State transitions:
//     IDLE       → LOAD       : start asserted
//     LOAD       → ASSIGN     : load_done (all N points latched)
//     ASSIGN     → UPDATE     : assign_done (all points processed)
//     UPDATE     → CHECK_CONV : update_done (new centroids computed)
//     CHECK_CONV → ASSIGN     : !converged (continue iterating)
//     CHECK_CONV → IDLE       : converged (assert done to host)
// ============================================================================

`timescale 1ns/1ps

module fsm_controller (
    input  wire clk,
    input  wire rst_n,

    // Host interface
    input  wire start,
    output reg  done,

    // Datapath status inputs
    input  wire load_done,
    input  wire assign_done,
    input  wire update_done,
    input  wire converged,

    // Datapath control outputs
    output reg  do_load,
    output reg  do_assign,
    output reg  do_update,
    output reg  do_check,
    output reg  clear_accum         // pulse to reset centroid_accumulator
);

    // ── State encoding (one-hot for FPGA efficiency) ─────────────────────────
    localparam [4:0]
        IDLE       = 5'b00001,
        LOAD       = 5'b00010,
        ASSIGN     = 5'b00100,
        UPDATE     = 5'b01000,
        CHECK_CONV = 5'b10000;

    reg [4:0] state, next_state;

    // ── State register ────────────────────────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ── Next-state logic ──────────────────────────────────────────────────────
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:       if (start)        next_state = LOAD;
            LOAD:       if (load_done)    next_state = ASSIGN;
            ASSIGN:     if (assign_done)  next_state = UPDATE;
            UPDATE:     if (update_done)  next_state = CHECK_CONV;
            CHECK_CONV:                   next_state = converged ? IDLE : ASSIGN;
            default:                      next_state = IDLE;
        endcase
    end

    // ── Output logic (Moore) ──────────────────────────────────────────────────
    always @(*) begin
        // Defaults
        done        = 1'b0;
        do_load     = 1'b0;
        do_assign   = 1'b0;
        do_update   = 1'b0;
        do_check    = 1'b0;
        clear_accum = 1'b0;

        case (state)
            IDLE:       ; // idle, no outputs
            LOAD:       do_load     = 1'b1;
            ASSIGN:     begin
                            do_assign   = 1'b1;
                            clear_accum = 1'b0;   // accum cleared on entry (prev CHECK_CONV or LOAD)
                        end
            UPDATE:     do_update   = 1'b1;
            CHECK_CONV: begin
                            do_check    = 1'b1;
                            done        = converged;
                            clear_accum = !converged;  // clear before next ASSIGN iteration
                        end
        endcase
    end

endmodule
