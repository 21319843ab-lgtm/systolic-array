`timescale 1ns/1ps

module array_timing_tb;
    parameter int M = 4;
    parameter int N = 4;
    parameter int K = 4;
    parameter int DATA_W = 8;
    parameter int ACC_W = 32;
    parameter int unsigned SATURATE = 0;
    localparam int RUN_CYCLES = K + M + N - 2;
    localparam int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES);
    localparam int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1);

    logic clk, rst_n, start;
    logic [M*K*DATA_W-1:0] a_matrix_flat;
    logic [K*N*DATA_W-1:0] b_matrix_flat;
    logic [M*N*ACC_W-1:0] c_matrix_flat;
    logic busy, done;
    logic [M*N*ACC_W-1:0] result_flat;
    logic [MAC_COUNT_W-1:0] active_macs;
    logic [CYCLE_W-1:0] run_cycle;

    systolic_array_top #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W),
        .SATURATE(SATURATE)) dut (.*);
    systolic_array_sva #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)) sva (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(busy), .done(done),
        .load_c(dut.load_c), .step(dut.step), .run_cycle(run_cycle),
        .active_macs(active_macs), .a_captured(dut.u_controller.a_q),
        .b_captured(dut.u_controller.b_q), .c_captured(dut.u_controller.c_q));
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    integer i, j, t, expected_active, seen_cycles, total_macs;
    logic signed [ACC_W-1:0] expected_result;
    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        a_matrix_flat = '0;
        b_matrix_flat = '0;
        c_matrix_flat = '0;
        for (i = 0; i < M*K; i = i + 1) a_matrix_flat[i*DATA_W +: DATA_W] = 1;
        for (i = 0; i < K*N; i = i + 1) b_matrix_flat[i*DATA_W +: DATA_W] = 1;
        for (i = 0; i < M*N; i = i + 1)
            c_matrix_flat[i*ACC_W +: ACC_W] = ACC_W'(i);
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        seen_cycles = 0;
        total_macs = 0;
        while (!done) begin
            @(negedge clk);
            if (dut.step) begin
                t = integer'(run_cycle);
                expected_active = 0;
                for (i = 0; i < M; i = i + 1)
                    for (j = 0; j < N; j = j + 1)
                        if ((t-i-j >= 0) && (t-i-j < K)) expected_active = expected_active + 1;
                if (active_macs !== expected_active[MAC_COUNT_W-1:0])
                    $fatal(1, "cycle %0d active_macs=%0d expected=%0d", t, active_macs, expected_active);
                $display("[CYCLE] t=%0d macs=%0d", t, active_macs);
                total_macs = total_macs + integer'(active_macs);
                seen_cycles = seen_cycles + 1;
            end
        end
        if (seen_cycles != RUN_CYCLES) $fatal(1, "run cycles=%0d expected=%0d", seen_cycles, RUN_CYCLES);
        if (total_macs != M*N*K) $fatal(1, "total MACs=%0d expected=%0d", total_macs, M*N*K);
        for (i = 0; i < M*N; i = i + 1) begin
            expected_result = ACC_W'(i+K);
            if ($signed(result_flat[i*ACC_W +: ACC_W]) != expected_result)
                $fatal(1, "result[%0d]=%0d expected=%0d", i,
                    $signed(result_flat[i*ACC_W +: ACC_W]), i+K);
        end
        $display("[PASS] array timing M=%0d N=%0d K=%0d cycles=%0d macs=%0d result=correct",
                 M, N, K, seen_cycles, total_macs);
        $finish;
    end
endmodule
