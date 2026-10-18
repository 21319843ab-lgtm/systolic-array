`timescale 1ns/1ps

module matmul_tb;
    parameter int M = 4;
    parameter int N = 4;
    parameter int K = 4;
    parameter int DATA_W = 8;
    parameter int ACC_W = 32;
    parameter int unsigned SATURATE = 0;
    localparam int RUN_CYCLES = K + M + N - 2;
    localparam int CYCLE_W = (RUN_CYCLES <= 1) ? 1 : $clog2(RUN_CYCLES);
    localparam int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1);

    logic clk;
    logic rst_n;
    logic start;
    logic [M*K*DATA_W-1:0] a_flat;
    logic [K*N*DATA_W-1:0] b_flat;
    logic [M*N*ACC_W-1:0] c_flat;
    logic busy, done;
    logic [M*N*ACC_W-1:0] result_flat;
    logic [MAC_COUNT_W-1:0] active_macs;
    logic [CYCLE_W-1:0] run_cycle;
    logic [M*N*ACC_W-1:0] expected_flat;

    systolic_array_top #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W),
        .SATURATE(SATURATE)) dut (.*,
        .a_matrix_flat(a_flat), .b_matrix_flat(b_flat), .c_matrix_flat(c_flat));

    systolic_array_sva #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)) sva (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(busy), .done(done),
        .load_c(dut.load_c), .step(dut.step), .run_cycle(run_cycle),
        .active_macs(active_macs), .a_captured(dut.u_controller.a_q),
        .b_captured(dut.u_controller.b_q), .c_captured(dut.u_controller.c_q));

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    integer fd, rc, cases, case_id, idx, timeout;
    logic signed [DATA_W-1:0] data_value;
    logic signed [ACC_W-1:0] acc_value;
    string vector_file;

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        a_flat = '0;
        b_flat = '0;
        c_flat = '0;
        expected_flat = '0;
        if (!$value$plusargs("VECTOR_FILE=%s", vector_file)) vector_file = "sim/build/vectors.txt";
        fd = $fopen(vector_file, "r");
        if (fd == 0) $fatal(1, "cannot open vector file: %s", vector_file);
        rc = $fscanf(fd, "%d", cases);
        if (rc != 1) $fatal(1, "invalid vector count");

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        for (case_id = 0; case_id < cases; case_id = case_id + 1) begin
            for (idx = 0; idx < M*K; idx = idx + 1) begin
                rc = $fscanf(fd, "%d", data_value);
                if (rc != 1) $fatal(1, "truncated A at case %0d", case_id);
                a_flat[idx*DATA_W +: DATA_W] = data_value;
            end
            for (idx = 0; idx < K*N; idx = idx + 1) begin
                rc = $fscanf(fd, "%d", data_value);
                if (rc != 1) $fatal(1, "truncated B at case %0d", case_id);
                b_flat[idx*DATA_W +: DATA_W] = data_value;
            end
            for (idx = 0; idx < M*N; idx = idx + 1) begin
                rc = $fscanf(fd, "%d", acc_value);
                if (rc != 1) $fatal(1, "truncated C at case %0d", case_id);
                c_flat[idx*ACC_W +: ACC_W] = acc_value;
            end
            for (idx = 0; idx < M*N; idx = idx + 1) begin
                rc = $fscanf(fd, "%d", acc_value);
                if (rc != 1) $fatal(1, "truncated expected at case %0d", case_id);
                expected_flat[idx*ACC_W +: ACC_W] = acc_value;
            end

            start = 1;
            @(negedge clk);
            start = 0;
            timeout = 0;
            while (!done && timeout < RUN_CYCLES + 8) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!done) $fatal(1, "timeout at case %0d", case_id);
            if (result_flat !== expected_flat) begin
                for (idx = 0; idx < M*N; idx = idx + 1)
                    if (result_flat[idx*ACC_W +: ACC_W] !== expected_flat[idx*ACC_W +: ACC_W])
                        $display("mismatch case=%0d index=%0d got=%0d expected=%0d", case_id, idx,
                            $signed(result_flat[idx*ACC_W +: ACC_W]),
                            $signed(expected_flat[idx*ACC_W +: ACC_W]));
                $fatal(1, "matrix mismatch");
            end
            @(negedge clk);
        end
        $fclose(fd);
        $display("[PASS] parameterized matrix regression M=%0d N=%0d K=%0d DATA_W=%0d ACC_W=%0d SATURATE=%0d cases=%0d",
                 M, N, K, DATA_W, ACC_W, SATURATE, cases);
        $finish;
    end
endmodule
