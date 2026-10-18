`timescale 1ns/1ps

module systolic_array_top #(
    parameter int M = 4,
    parameter int N = 4,
    parameter int K = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int unsigned SATURATE = 0,
    parameter int RUN_CYCLES = K + M + N - 2,
    parameter int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES),
    parameter int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1)
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         start,
    input  logic [M*K*DATA_W-1:0]        a_matrix_flat,
    input  logic [K*N*DATA_W-1:0]        b_matrix_flat,
    input  logic [M*N*ACC_W-1:0]         c_matrix_flat,
    output logic                         busy,
    output logic                         done,
    output logic [M*N*ACC_W-1:0]         result_flat,
    output logic [MAC_COUNT_W-1:0]       active_macs,
    output logic [CYCLE_W-1:0]           run_cycle
);
    logic clear, load_c, step;
    logic [M*DATA_W-1:0] a_edge;
    logic [N*DATA_W-1:0] b_edge;
    logic [M-1:0] a_valid;
    logic [N-1:0] b_valid;
    logic [M*N*ACC_W-1:0] c_captured;

    os_controller #(
        .M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) u_controller (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_matrix_flat(a_matrix_flat), .b_matrix_flat(b_matrix_flat),
        .c_matrix_flat(c_matrix_flat), .busy(busy), .done(done),
        .array_clear(clear), .load_c(load_c), .step(step),
        .a_edge_flat(a_edge), .b_edge_flat(b_edge),
        .a_valid_edge(a_valid), .b_valid_edge(b_valid),
        .c_captured_flat(c_captured), .run_cycle(run_cycle)
    );

    os_systolic_array #(
        .M(M), .N(N), .DATA_W(DATA_W), .ACC_W(ACC_W), .SATURATE(SATURATE)
    ) u_array (
        .clk(clk), .rst_n(rst_n), .clear(clear), .load_c(load_c), .step(step),
        .a_edge_flat(a_edge), .b_edge_flat(b_edge),
        .a_valid_edge(a_valid), .b_valid_edge(b_valid),
        .c_init_flat(c_captured), .result_flat(result_flat),
        .active_macs(active_macs)
    );
endmodule
