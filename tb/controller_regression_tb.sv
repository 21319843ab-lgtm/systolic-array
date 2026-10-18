`timescale 1ns/1ps

module controller_regression_tb;
    localparam int M=2, N=3, K=2, DATA_W=8, ACC_W=32;
    localparam int RUN_CYCLES=K+M+N-2;
    localparam int CYCLE_W=(RUN_CYCLES<=1)?1:$clog2(RUN_CYCLES);
    localparam int MAC_COUNT_W=$clog2(M*N+1);
    logic clk, rst_n, start;
    logic [M*K*DATA_W-1:0] a_matrix_flat;
    logic [K*N*DATA_W-1:0] b_matrix_flat;
    logic [M*N*ACC_W-1:0] c_matrix_flat;
    logic busy,done;
    logic [M*N*ACC_W-1:0] result_flat;
    logic [MAC_COUNT_W-1:0] active_macs;
    logic [CYCLE_W-1:0] run_cycle;
    integer i;

    systolic_array_top #(.M(M),.N(N),.K(K),.DATA_W(DATA_W),.ACC_W(ACC_W)) dut(.*);
    systolic_array_sva #(.M(M), .N(N), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)) sva (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(busy), .done(done),
        .load_c(dut.load_c), .step(dut.step), .run_cycle(run_cycle),
        .active_macs(active_macs), .a_captured(dut.u_controller.a_q),
        .b_captured(dut.u_controller.b_q), .c_captured(dut.u_controller.c_q));
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic launch;
        begin @(negedge clk); start=1; @(negedge clk); start=0; end
    endtask
    task automatic wait_done;
        integer guard;
        begin
            guard=0;
            while(!done && guard<RUN_CYCLES+8) begin @(negedge clk); guard=guard+1; end
            if(!done) $fatal(1,"done timeout");
        end
    endtask

    initial begin
        rst_n=1'b0; start=1'b0; a_matrix_flat='0; b_matrix_flat='0; c_matrix_flat='0;
        for(i=0;i<M*K;i=i+1) a_matrix_flat[i*DATA_W+:DATA_W]=DATA_W'(i+1);
        for(i=0;i<K*N;i=i+1) b_matrix_flat[i*DATA_W+:DATA_W]=DATA_W'(i+1);
        for(i=0;i<M*N;i=i+1) c_matrix_flat[i*ACC_W+:ACC_W]=ACC_W'(10+i);
        repeat(3) @(posedge clk); rst_n=1;
        launch();
        if(!busy) $fatal(1,"busy did not assert");
        @(negedge clk); start=1; a_matrix_flat='0;
        @(negedge clk); start=0;
        wait_done();
        $display("[PASS] CTRL busy start ignored and captured inputs stable");
        @(negedge clk);
        if(done) $fatal(1,"done wider than one cycle");
        $display("[PASS] CTRL done is a one-cycle pulse");

        // Reset must abort an in-flight operation and permit a clean restart.
        for(i=0;i<M*K;i=i+1) a_matrix_flat[i*DATA_W+:DATA_W]=1;
        for(i=0;i<K*N;i=i+1) b_matrix_flat[i*DATA_W+:DATA_W]=1;
        c_matrix_flat='0;
        launch(); @(negedge clk); rst_n=0; @(negedge clk); rst_n=1;
        if(busy || done) $fatal(1,"reset did not abort");
        launch(); wait_done();
        for(i=0;i<M*N;i=i+1)
            if($signed(result_flat[i*ACC_W+:ACC_W]) != K) $fatal(1,"restart result mismatch");
        $display("[PASS] CTRL reset abort and clean restart");
        $finish;
    end
endmodule
