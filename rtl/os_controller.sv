`timescale 1ns/1ps

module os_controller #(
    parameter int M = 4,
    parameter int N = 4,
    parameter int K = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int RUN_CYCLES = K + M + N - 2,
    parameter int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES)
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         start,
    input  logic [M*K*DATA_W-1:0]        a_matrix_flat,
    input  logic [K*N*DATA_W-1:0]        b_matrix_flat,
    input  logic [M*N*ACC_W-1:0]         c_matrix_flat,
    output logic                         busy,
    output logic                         done,
    output logic                         array_clear,
    output logic                         load_c,
    output logic                         step,
    output logic [M*DATA_W-1:0]          a_edge_flat,
    output logic [N*DATA_W-1:0]          b_edge_flat,
    output logic [M-1:0]                 a_valid_edge,
    output logic [N-1:0]                 b_valid_edge,
    output logic [M*N*ACC_W-1:0]         c_captured_flat,
    output logic [CYCLE_W-1:0]           run_cycle
);
    typedef enum logic [1:0] {IDLE, LOAD_C, RUN, DONE} state_t;
    state_t state_q;
    logic [M*K*DATA_W-1:0] a_q;
    logic [K*N*DATA_W-1:0] b_q;
    logic [M*N*ACC_W-1:0]  c_q;
    logic [CYCLE_W-1:0] cycle_q;

    initial begin
        if (M < 1 || N < 1 || K < 1) $fatal(1, "M, N, and K must be >= 1");
        if (DATA_W < 1) $fatal(1, "DATA_W must be >= 1");
        if (ACC_W < 2*DATA_W) $fatal(1, "ACC_W must be >= 2*DATA_W");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= IDLE;
            cycle_q <= '0;
            a_q <= '0;
            b_q <= '0;
            c_q <= '0;
        end else begin
            case (state_q)
                IDLE: begin
                    cycle_q <= '0;
                    if (start) begin
                        a_q <= a_matrix_flat;
                        b_q <= b_matrix_flat;
                        c_q <= c_matrix_flat;
                        state_q <= LOAD_C;
                    end
                end
                LOAD_C: begin
                    cycle_q <= '0;
                    state_q <= RUN;
                end
                RUN: begin
                    if (cycle_q == CYCLE_W'(RUN_CYCLES-1)) begin
                        state_q <= DONE;
                    end else begin
                        cycle_q <= cycle_q + 1'b1;
                    end
                end
                DONE: state_q <= IDLE;
                default: state_q <= IDLE;
            endcase
        end
    end

    integer r, c, k_index;
    always_comb begin
        busy            = (state_q == LOAD_C) || (state_q == RUN);
        done            = (state_q == DONE);
        array_clear     = (state_q == IDLE) && start;
        load_c          = (state_q == LOAD_C);
        step            = (state_q == RUN);
        c_captured_flat = c_q;
        run_cycle       = cycle_q;
        a_edge_flat     = '0;
        b_edge_flat     = '0;
        a_valid_edge    = '0;
        b_valid_edge    = '0;
        k_index         = 0;

        if (state_q == RUN) begin
            for (r = 0; r < M; r = r + 1) begin
                k_index = integer'(cycle_q);
                k_index = k_index - r;
                if ((k_index >= 0) && (k_index < K)) begin
                    a_edge_flat[r*DATA_W +: DATA_W] = a_q[(r*K+k_index)*DATA_W +: DATA_W];
                    a_valid_edge[r] = 1'b1;
                end
            end
            for (c = 0; c < N; c = c + 1) begin
                k_index = integer'(cycle_q);
                k_index = k_index - c;
                if ((k_index >= 0) && (k_index < K)) begin
                    b_edge_flat[c*DATA_W +: DATA_W] = b_q[(k_index*N+c)*DATA_W +: DATA_W];
                    b_valid_edge[c] = 1'b1;
                end
            end
        end
    end
endmodule
