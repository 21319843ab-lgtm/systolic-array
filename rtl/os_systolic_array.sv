`timescale 1ns/1ps

module os_systolic_array #(
    parameter int M = 4,
    parameter int N = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter int unsigned SATURATE = 0,
    parameter int MAC_COUNT_W = ((M*N) <= 1) ? 1 : $clog2(M*N+1)
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         clear,
    input  logic                         load_c,
    input  logic                         step,
    input  logic [M*DATA_W-1:0]          a_edge_flat,
    input  logic [N*DATA_W-1:0]          b_edge_flat,
    input  logic [M-1:0]                 a_valid_edge,
    input  logic [N-1:0]                 b_valid_edge,
    input  logic [M*N*ACC_W-1:0]         c_init_flat,
    output logic [M*N*ACC_W-1:0]         result_flat,
    output logic [MAC_COUNT_W-1:0]       active_macs
);
    logic signed [DATA_W-1:0] a_hop [0:M-1][0:N-1];
    logic signed [DATA_W-1:0] b_hop [0:M-1][0:N-1];
    logic                      av_hop[0:M-1][0:N-1];
    logic                      bv_hop[0:M-1][0:N-1];
    logic signed [ACC_W-1:0]  acc   [0:M-1][0:N-1];

    initial begin
        if (M < 1 || N < 1) $fatal(1, "M and N must be >= 1");
    end

    genvar r, c;
    generate
        for (r = 0; r < M; r++) begin : gen_rows
            for (c = 0; c < N; c++) begin : gen_cols
                wire signed [DATA_W-1:0] pe_a_in =
                    (c == 0) ? $signed(a_edge_flat[r*DATA_W +: DATA_W]) : a_hop[r][c-1];
                wire signed [DATA_W-1:0] pe_b_in =
                    (r == 0) ? $signed(b_edge_flat[c*DATA_W +: DATA_W]) : b_hop[r-1][c];
                wire pe_av_in = (c == 0) ? a_valid_edge[r] : av_hop[r][c-1];
                wire pe_bv_in = (r == 0) ? b_valid_edge[c] : bv_hop[r-1][c];

                os_pe #(.DATA_W(DATA_W), .ACC_W(ACC_W), .SATURATE(SATURATE)) u_pe (
                    .clk(clk), .rst_n(rst_n), .clear(clear),
                    .load_acc(load_c), .step(step),
                    .a_in(pe_a_in), .b_in(pe_b_in),
                    .a_valid_in(pe_av_in), .b_valid_in(pe_bv_in),
                    .acc_init($signed(c_init_flat[(r*N+c)*ACC_W +: ACC_W])),
                    .a_out(a_hop[r][c]), .b_out(b_hop[r][c]),
                    .a_valid_out(av_hop[r][c]), .b_valid_out(bv_hop[r][c]),
                    .acc_out(acc[r][c])
                );

                always_comb result_flat[(r*N+c)*ACC_W +: ACC_W] = acc[r][c];
            end
        end
    endgenerate

    integer i, j;
    always_comb begin
        active_macs = '0;
        for (i = 0; i < M; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (((j == 0) ? a_valid_edge[i] : av_hop[i][j-1]) &&
                    ((i == 0) ? b_valid_edge[j] : bv_hop[i-1][j]))
                    active_macs = active_macs + 1'b1;
            end
        end
    end
endmodule
