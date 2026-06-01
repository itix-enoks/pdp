`timescale 1ns/1ps

module riscv_aes_unit (
    input  logic [31:0] rs1_i,
    input  logic [31:0] rs2_i,
    input  logic [1:0]  bs_i,
    input  logic        mix_i,
    input  logic        col_i,
    output logic [31:0] result_o
);
    logic [7:0]  si;
    logic [7:0]  so;
    logic [7:0]  xt2_so, xt3_so;
    logic [31:0] rot_in;
    logic [31:0] rot_out;

    // Select input byte from rs2 based on bs
    always_comb begin
        unique case (bs_i)
            2'b00: si = rs2_i[7:0];
            2'b01: si = rs2_i[15:8];
            2'b10: si = rs2_i[23:16];
            2'b11: si = rs2_i[31:24];
            default: si = 8'h00;
        endcase
    end

    aes_sbox u_sbox (.in_i(si), .out_o(so));

    assign xt2_so = (so << 1) ^ ({8{so[7]}} & 8'h1b);
    assign xt3_so = xt2_so ^ so;

    assign rot_in = mix_i ? {xt3_so, so, so, xt2_so} : {24'h0, so};

    always_comb begin
        unique case (bs_i)
            2'b00: rot_out = rot_in;
            2'b01: rot_out = {rot_in[23:0],  rot_in[31:24]};
            2'b10: rot_out = {rot_in[15:0],  rot_in[31:16]};
            2'b11: rot_out = {rot_in[7:0],   rot_in[31:8]};
            default: rot_out = 32'h0;
        endcase
    end

    // ---- Column-fused mode: 4 parallel S-boxes + full MixColumns ----
    logic [7:0] c0, c1, c2, c3;
    logic [7:0] s0, s1, s2, s3;
    logic [7:0] x2_0, x3_0, x2_1, x3_1, x2_2, x3_2, x2_3, x3_3;
    logic [31:0] col_mix;

    assign c0 = rs2_i[7:0];
    assign c1 = rs2_i[15:8];
    assign c2 = rs2_i[23:16];
    assign c3 = rs2_i[31:24];

    aes_sbox u_sbox0 (.in_i(c0), .out_o(s0));
    aes_sbox u_sbox1 (.in_i(c1), .out_o(s1));
    aes_sbox u_sbox2 (.in_i(c2), .out_o(s2));
    aes_sbox u_sbox3 (.in_i(c3), .out_o(s3));

    assign x2_0 = (s0 << 1) ^ ({8{s0[7]}} & 8'h1b);
    assign x3_0 = x2_0 ^ s0;
    assign x2_1 = (s1 << 1) ^ ({8{s1[7]}} & 8'h1b);
    assign x3_1 = x2_1 ^ s1;
    assign x2_2 = (s2 << 1) ^ ({8{s2[7]}} & 8'h1b);
    assign x3_2 = x2_2 ^ s2;
    assign x2_3 = (s3 << 1) ^ ({8{s3[7]}} & 8'h1b);
    assign x3_3 = x2_3 ^ s3;

    assign col_mix[7:0]   = x2_0 ^ x3_1 ^ s2   ^ s3;
    assign col_mix[15:8]  = s0   ^ x2_1 ^ x3_2 ^ s3;
    assign col_mix[23:16] = s0   ^ s1   ^ x2_2 ^ x3_3;
    assign col_mix[31:24] = x3_0 ^ s1   ^ s2   ^ x2_3;

    assign result_o = col_i ? (col_mix ^ rs1_i) : (rot_out ^ rs1_i);

endmodule
