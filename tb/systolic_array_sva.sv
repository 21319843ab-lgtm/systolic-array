`timescale 1ns/1ps

// Protocol/timing checker instantiated by the testbenches. Keeping assertions
// outside synthesizable RTL lets the same design be used by tools without SVA.
module systolic_array_sva #(
    parameter int M = 4,
    parameter int N = 4,
    parameter int K = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W = 32,
    parameter int RUN_CYCLES = K + M + N - 2,
    parameter int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES),
    parameter int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1)
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic busy,
    input logic done,
    input logic load_c,
    input logic step,
    input logic [CYCLE_W-1:0] run_cycle,
    input logic [MAC_COUNT_W-1:0] active_macs,
    input logic [M*K*DATA_W-1:0] a_captured,
    input logic [K*N*DATA_W-1:0] b_captured,
    input logic [M*N*ACC_W-1:0] c_captured
);
    property p_done_one_cycle;
        @(posedge clk) disable iff (!rst_n) done |=> !done;
    endproperty
    a_done_one_cycle: assert property (p_done_one_cycle)
        else $error("done must be a one-cycle pulse");

    property p_done_excludes_busy;
        @(posedge clk) disable iff (!rst_n) done |-> !busy;
    endproperty
    a_done_excludes_busy: assert property (p_done_excludes_busy)
        else $error("done and busy cannot be high together");

    property p_start_to_load;
        @(posedge clk) disable iff (!rst_n)
            (start && !busy && !done) |=> load_c;
    endproperty
    a_start_to_load: assert property (p_start_to_load)
        else $error("accepted start must enter C-load phase");

    property p_load_to_run;
        @(posedge clk) disable iff (!rst_n) load_c |=> step;
    endproperty
    a_load_to_run: assert property (p_load_to_run)
        else $error("C-load phase must be followed by run phase");

    property p_last_run_to_done;
        @(posedge clk) disable iff (!rst_n)
            (step && run_cycle == CYCLE_W'(RUN_CYCLES-1)) |=> done;
    endproperty
    a_last_run_to_done: assert property (p_last_run_to_done)
        else $error("last run cycle must be followed by done");

    property p_run_cycle_increments;
        @(posedge clk) disable iff (!rst_n)
            (step && run_cycle < CYCLE_W'(RUN_CYCLES-1))
            |=> (step && run_cycle == ($past(run_cycle) + 1'b1));
    endproperty
    a_run_cycle_increments: assert property (p_run_cycle_increments)
        else $error("run_cycle did not increment by one");

    property p_captured_inputs_stable_while_busy;
        @(posedge clk) disable iff (!rst_n)
            busy |=> ($stable(a_captured) && $stable(b_captured) && $stable(c_captured));
    endproperty
    a_captured_inputs_stable: assert property (p_captured_inputs_stable_while_busy)
        else $error("captured matrix changed during transaction");

    property p_active_macs_bounded;
        @(posedge clk) disable iff (!rst_n)
            step |-> (active_macs <= MAC_COUNT_W'(M*N));
    endproperty
    a_active_macs_bounded: assert property (p_active_macs_bounded)
        else $error("active_macs exceeds physical PE count");

    // These cover properties feed Verilator's assertion coverage database when
    // --coverage is enabled; the portable coverage TB also reports named bins.
    c_accepted_start: cover property (@(posedge clk) disable iff (!rst_n)
        start && !busy && !done);
    c_busy_start: cover property (@(posedge clk) disable iff (!rst_n)
        start && busy);
    c_load_phase: cover property (@(posedge clk) disable iff (!rst_n) load_c);
    c_first_run: cover property (@(posedge clk) disable iff (!rst_n)
        step && run_cycle == '0);
    c_last_run: cover property (@(posedge clk) disable iff (!rst_n)
        step && run_cycle == CYCLE_W'(RUN_CYCLES-1));
    c_done: cover property (@(posedge clk) disable iff (!rst_n) done);
endmodule
