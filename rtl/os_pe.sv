`timescale 1ns/1ps

module os_pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int unsigned SATURATE = 0
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         clear,
    input  logic                         load_acc,
    input  logic                         step,
    input  logic signed [DATA_W-1:0]     a_in,
    input  logic signed [DATA_W-1:0]     b_in,
    input  logic                         a_valid_in,
    input  logic                         b_valid_in,
    input  logic signed [ACC_W-1:0]      acc_init,
    output logic signed [DATA_W-1:0]     a_out,
    output logic signed [DATA_W-1:0]     b_out,
    output logic                         a_valid_out,
    output logic                         b_valid_out,
    output logic signed [ACC_W-1:0]      acc_out
);
    localparam int PROD_W = 2 * DATA_W;
    logic signed [PROD_W-1:0] product;
    logic signed [ACC_W-1:0]  product_ext;
    logic signed [ACC_W-1:0]  wrapped_sum;
    localparam logic signed [ACC_W-1:0] ACC_MAX = {1'b0, {(ACC_W-1){1'b1}}};
    localparam logic signed [ACC_W-1:0] ACC_MIN = {1'b1, {(ACC_W-1){1'b0}}};

    initial begin
        if (DATA_W < 1) $fatal(1, "DATA_W must be >= 1");
        if (ACC_W < PROD_W) $fatal(1, "ACC_W must be >= 2*DATA_W");
    end

    always_comb begin
        product     = a_in * b_in;
        product_ext = {{(ACC_W-PROD_W){product[PROD_W-1]}}, product};
        wrapped_sum = acc_out + product_ext;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out       <= '0;
            b_out       <= '0;
            a_valid_out <= 1'b0;
            b_valid_out <= 1'b0;
            acc_out     <= '0;
        end else if (clear) begin
            a_out       <= '0;
            b_out       <= '0;
            a_valid_out <= 1'b0;
            b_valid_out <= 1'b0;
            acc_out     <= '0;
        end else if (load_acc) begin
            a_out       <= '0;
            b_out       <= '0;
            a_valid_out <= 1'b0;
            b_valid_out <= 1'b0;
            acc_out     <= acc_init;
        end else if (step) begin
            a_out       <= a_in;
            b_out       <= b_in;
            a_valid_out <= a_valid_in;
            b_valid_out <= b_valid_in;
            if (a_valid_in && b_valid_in) begin
                if ((SATURATE != 0) && (acc_out[ACC_W-1] == product_ext[ACC_W-1]) &&
                    (wrapped_sum[ACC_W-1] != acc_out[ACC_W-1]))
                    acc_out <= acc_out[ACC_W-1] ? ACC_MIN : ACC_MAX;
                else
                    acc_out <= wrapped_sum;
            end
        end
    end
endmodule
