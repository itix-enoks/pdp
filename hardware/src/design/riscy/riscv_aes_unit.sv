`timescale 1ns/1ps

module riscv_aes_unit (
    input  logic [31:0] rs1_i,
    input  logic [31:0] rs2_i,
    input  logic [1:0]  bs_i,
    input  logic        mix_i,    // 1 = aes32esmi (MixColumns), 0 = aes32esi
    output logic [31:0] result_o
);
    logic [7:0]  si;
    logic [7:0]  so;
    logic [7:0]  xt2_so;
    logic [7:0]  xt3_so;
    logic [31:0] rot_in;
    logic [31:0] rot_out;

    // Select input byte from rs2 based on bs
    always_comb begin
        unique case (bs_i)
            2'b00: si = rs2_i[7:0];
            2'b01: si = rs2_i[15:8];
            2'b10: si = rs2_i[23:16];
            2'b11: si = rs2_i[31:24];
        endcase
    end

    aes_sbox u_sbox (.in_i(si), .out_o(so));

    //  xt2(x) = (x<<1) ^ (x[7] ? 0x1B : 0)
    assign xt2_so = (so << 1) ^ ({8{so[7]}} & 8'h1b);
    //  xt3(x) = xt2(x) ^ x
    assign xt3_so = xt2_so ^ so;

    //  {xt3(so), so, so, xt2(so)}
    //  {0, 0, 0, so}
    assign rot_in = mix_i ? {xt3_so, so, so, xt2_so} : {24'h0, so};

    // Rotate left by 8*bs_i bits
    always_comb begin
        unique case (bs_i)
            2'b00: rot_out = rot_in;
            2'b01: rot_out = {rot_in[23:0],  rot_in[31:24]};
            2'b10: rot_out = {rot_in[15:0],  rot_in[31:16]};
            2'b11: rot_out = {rot_in[7:0],   rot_in[31:8]};
        endcase
    end

    assign result_o = rot_out ^ rs1_i;

endmodule
