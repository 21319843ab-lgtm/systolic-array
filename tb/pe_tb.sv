`timescale 1ns/1ps

module pe_tb;
    localparam int DATA_W = 8;
    localparam int ACC_W = 32;
    logic clk, rst_n, clear, load_acc, step;
    logic signed [DATA_W-1:0] a_in, b_in;
    logic a_valid_in, b_valid_in;
    logic signed [ACC_W-1:0] acc_init;
    logic signed [DATA_W-1:0] a_out, b_out;
    logic a_valid_out, b_valid_out;
    logic signed [ACC_W-1:0] acc_out;
    integer checks = 0;

    os_pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic tick;
        begin @(negedge clk); checks = checks + 1; end
    endtask

    initial begin
        rst_n = 1'b0; clear = 1'b0; load_acc = 1'b0; step = 1'b0;
        a_in = '0; b_in = '0; a_valid_in = 1'b0; b_valid_in = 1'b0; acc_init = '0;
        repeat (2) @(posedge clk); rst_n = 1;
        acc_init = 32'sd17; load_acc = 1; tick(); load_acc = 0;
        if (acc_out != 17) $fatal(1, "C load failed");
        a_in = -8'sd7; b_in = 8'sd9; a_valid_in = 1; b_valid_in = 1; step = 1; tick();
        if (acc_out != -46 || a_out != -7 || b_out != 9) $fatal(1, "valid MAC failed");
        a_in = 8'sd99; b_in = 8'sd99; b_valid_in = 0; tick();
        if (acc_out != -46) $fatal(1, "invalid MAC changed accumulator");
        clear = 1; tick(); clear = 0; step = 0;
        if (acc_out != 0 || a_valid_out || b_valid_out) $fatal(1, "clear failed");
        $display("[PASS] PE directed checks=%0d", checks);
        $finish;
    end
endmodule
