`timescale 1ns/1ps

// Portable functional coverage: named bins are tracked explicitly so the same
// report works in Verilator and simulators without covergroup support.
module functional_coverage_tb;
    parameter int M = 2;
    parameter int N = 2;
    parameter int K = 3;
    parameter int DATA_W = 8;
    parameter int ACC_W = 16;
    parameter int unsigned SATURATE = 0;
    localparam int RUN_CYCLES = K + M + N - 2;
    localparam int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES);
    localparam int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1);
    localparam logic signed [ACC_W-1:0] ACC_MAX = {1'b0, {(ACC_W-1){1'b1}}};
    localparam logic signed [ACC_W-1:0] ACC_MIN = {1'b1, {(ACC_W-1){1'b0}}};

    logic clk, rst_n, start;
    logic [M*K*DATA_W-1:0] a_matrix_flat;
    logic [K*N*DATA_W-1:0] b_matrix_flat;
    logic [M*N*ACC_W-1:0] c_matrix_flat;
    logic busy, done;
    logic [M*N*ACC_W-1:0] result_flat;
    logic [MAC_COUNT_W-1:0] active_macs;
    logic [CYCLE_W-1:0] run_cycle;

    bit cov_accepted_start, cov_busy_start, cov_done, cov_done_pulse;
    bit cov_reset_abort, cov_clean_restart, cov_zero, cov_positive;
    bit cov_negative, cov_extreme, cov_first_wave, cov_peak_wave, cov_last_wave;
    bit cov_arithmetic_mode;
    integer hit_count;
    logic signed [ACC_W-1:0] expected_value;

    systolic_array_top #(
        .M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W), .SATURATE(SATURATE)
    ) dut (.*);

    systolic_array_sva #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)) sva (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(busy), .done(done),
        .load_c(dut.load_c), .step(dut.step), .run_cycle(run_cycle),
        .active_macs(active_macs), .a_captured(dut.u_controller.a_q),
        .b_captured(dut.u_controller.b_q), .c_captured(dut.u_controller.c_q));

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic drive_uniform(input logic signed [DATA_W-1:0] a_value,
                                 input logic signed [DATA_W-1:0] b_value,
                                 input logic signed [ACC_W-1:0] c_value);
        integer q;
        begin
            for (q = 0; q < M*K; q = q + 1)
                a_matrix_flat[q*DATA_W +: DATA_W] = a_value;
            for (q = 0; q < K*N; q = q + 1)
                b_matrix_flat[q*DATA_W +: DATA_W] = b_value;
            for (q = 0; q < M*N; q = q + 1)
                c_matrix_flat[q*ACC_W +: ACC_W] = c_value;
        end
    endtask

    task automatic launch;
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            cov_accepted_start = 1'b1;
        end
    endtask

    task automatic observe_until_done;
        integer guard;
        begin
            guard = 0;
            while (!done && guard < RUN_CYCLES+8) begin
                @(negedge clk);
                guard = guard + 1;
                if (dut.step && run_cycle == '0) cov_first_wave = 1'b1;
                if (dut.step && active_macs == MAC_COUNT_W'(M*N)) cov_peak_wave = 1'b1;
                if (dut.step && run_cycle == CYCLE_W'(RUN_CYCLES-1)) cov_last_wave = 1'b1;
            end
            if (!done) $fatal(1, "coverage test transaction timeout");
            cov_done = 1'b1;
            @(negedge clk);
            if (done) $fatal(1, "done pulse wider than one cycle");
            cov_done_pulse = 1'b1;
        end
    endtask

    task automatic check_uniform_result(input logic signed [ACC_W-1:0] expected);
        integer q;
        begin
            for (q = 0; q < M*N; q = q + 1)
                if ($signed(result_flat[q*ACC_W +: ACC_W]) != expected)
                    $fatal(1, "coverage result[%0d]=%0d expected=%0d", q,
                           $signed(result_flat[q*ACC_W +: ACC_W]), expected);
        end
    endtask

    initial begin
        rst_n = 1'b0; start = 1'b0;
        a_matrix_flat = '0; b_matrix_flat = '0; c_matrix_flat = '0;
        cov_accepted_start = 0; cov_busy_start = 0; cov_done = 0;
        cov_done_pulse = 0; cov_reset_abort = 0; cov_clean_restart = 0;
        cov_zero = 0; cov_positive = 0; cov_negative = 0; cov_extreme = 0;
        cov_first_wave = 0; cov_peak_wave = 0; cov_last_wave = 0;
        cov_arithmetic_mode = 0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Zero/positive data, accepted start, and a second start while busy.
        drive_uniform(DATA_W'(1), DATA_W'(1), ACC_W'(0));
        cov_zero = 1'b1; cov_positive = 1'b1;
        launch();
        @(negedge clk); start = 1'b1; a_matrix_flat = '0;
        @(negedge clk); start = 1'b0; cov_busy_start = 1'b1;
        observe_until_done();
        check_uniform_result(ACC_W'(K));

        // Reset abort followed by a clean restart with signed negative data.
        drive_uniform(DATA_W'(-1), DATA_W'(1), ACC_W'(0)); cov_negative = 1'b1;
        launch();
        @(negedge clk); rst_n = 1'b0;
        @(negedge clk); rst_n = 1'b1; cov_reset_abort = 1'b1;
        if (busy || done) $fatal(1, "reset did not abort coverage transaction");
        launch(); observe_until_done();
        expected_value = ACC_W'(-K);
        check_uniform_result(expected_value);
        cov_clean_restart = 1'b1;

        // Positive overflow distinguishes wrap from saturation.
        drive_uniform(DATA_W'(1), DATA_W'(1), ACC_MAX); cov_extreme = 1'b1;
        launch(); observe_until_done();
        expected_value = (SATURATE != 0) ? ACC_MAX : (ACC_MAX + ACC_W'(K));
        check_uniform_result(expected_value);

        // Negative overflow distinguishes wrap from saturation.
        drive_uniform(DATA_W'(-1), DATA_W'(1), ACC_MIN);
        launch(); observe_until_done();
        expected_value = (SATURATE != 0) ? ACC_MIN : (ACC_MIN - ACC_W'(K));
        check_uniform_result(expected_value);
        cov_arithmetic_mode = 1'b1;

        hit_count = 0;
        hit_count += cov_accepted_start ? 1 : 0;
        hit_count += cov_busy_start ? 1 : 0;
        hit_count += cov_done ? 1 : 0;
        hit_count += cov_done_pulse ? 1 : 0;
        hit_count += cov_reset_abort ? 1 : 0;
        hit_count += cov_clean_restart ? 1 : 0;
        hit_count += cov_zero ? 1 : 0;
        hit_count += cov_positive ? 1 : 0;
        hit_count += cov_negative ? 1 : 0;
        hit_count += cov_extreme ? 1 : 0;
        hit_count += cov_first_wave ? 1 : 0;
        hit_count += cov_peak_wave ? 1 : 0;
        hit_count += cov_last_wave ? 1 : 0;
        hit_count += cov_arithmetic_mode ? 1 : 0;
        $display("[COVERAGE] SATURATE=%0d named_bins=%0d/14 coverage=%0.2f%%",
                 SATURATE, hit_count, 100.0*hit_count/14.0);
        if (hit_count != 14) $fatal(1, "functional coverage target not met");
        $display("[PASS] functional coverage and arithmetic-mode checks");
        $finish;
    end
endmodule
