`timescale 1ns/1ps

module tb_riscv_aes_unit;

    logic [31:0] rs1 = 32'h0, rs2 = 32'h0, result;
    logic [1:0]  bs  = 2'b00;
    logic        mix = 1'b0;

    riscv_aes_unit dut (
        .rs1_i(rs1),
        .rs2_i(rs2),
        .bs_i(bs),
        .mix_i(mix),
        .result_o(result)
    );

    integer pass_count;
    integer fail_count;

    task automatic check_vec(
        input string      grp,
        input integer     idx,
        input logic [31:0] expected
    );
        #1;
        if (result === expected) begin
            $display("  PASS [%s-%0d]: got 0x%08X", grp, idx, result);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [%s-%0d]: expected 0x%08X, got 0x%08X", grp, idx, expected, result);
            fail_count = fail_count + 1;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // Group 1: SBox spot checks (mix=0, bs=0, rs1=0)
        $display("--- Group 1: SBox spot checks ---");
        mix = 1'b0; bs = 2'b00; rs1 = 32'h0;
        rs2 = 32'h00000000; check_vec("G1", 1, 32'h00000063); // SBox[0x00]=0x63
        rs2 = 32'h00000001; check_vec("G1", 2, 32'h0000007C); // SBox[0x01]=0x7C
        rs2 = 32'h00000010; check_vec("G1", 3, 32'h000000CA); // SBox[0x10]=0xCA
        rs2 = 32'h00000053; check_vec("G1", 4, 32'h000000ED); // SBox[0x53]=0xED
        rs2 = 32'h00000052; check_vec("G1", 5, 32'h00000000); // SBox[0x52]=0x00
        rs2 = 32'h000000FF; check_vec("G1", 6, 32'h00000016); // SBox[0xFF]=0x16

        // Group 2: byte_select at all bs (mix=0, rs1=0, rs2=0xAABBCCDD)
        $display("--- Group 2: byte_select ---");
        mix = 1'b0; rs1 = 32'h0; rs2 = 32'hAABBCCDD;
        bs = 2'b00; check_vec("G2", 1, 32'h000000C1); // SBox[0xDD]=0xC1
        bs = 2'b01; check_vec("G2", 2, 32'h00004B00); // SBox[0xCC]=0x4B, rotL8
        bs = 2'b10; check_vec("G2", 3, 32'h00EA0000); // SBox[0xBB]=0xEA, rotL16
        bs = 2'b11; check_vec("G2", 4, 32'hAC000000); // SBox[0xAA]=0xAC, rotL24

        // Group 3: aes32esmi MixColumns math (mix=1, bs=0, rs1=0)
        $display("--- Group 3: MixColumns math ---");
        mix = 1'b1; bs = 2'b00; rs1 = 32'h0;
        rs2 = 32'h00000000; check_vec("G3", 1, 32'hA56363C6); // so=0x63,xt2=0xC6,xt3=0xA5
        rs2 = 32'h00000053; check_vec("G3", 2, 32'h2CEDEDC1); // so=0xED,xt2=0xC1,xt3=0x2C
        rs2 = 32'h000000FF; check_vec("G3", 3, 32'h3A16162C); // so=0x16,xt2=0x2C,xt3=0x3A

        // Group 4: rotation (mix=1, rs1=0, byte 0x53 at bs)
        $display("--- Group 4: rotation ---");
        mix = 1'b1; rs1 = 32'h0;
        rs2 = 32'h00000053; bs = 2'b00; check_vec("G4", 1, 32'h2CEDEDC1);
        rs2 = 32'h00005300; bs = 2'b01; check_vec("G4", 2, 32'hEDEDC12C);
        rs2 = 32'h00530000; bs = 2'b10; check_vec("G4", 3, 32'hEDC12CED);
        rs2 = 32'h53000000; bs = 2'b11; check_vec("G4", 4, 32'hC12CEDED);

        // Group 5: aes32esi placement (mix=0, rs1=0, byte 0x53 at bs)
        $display("--- Group 5: esi placement ---");
        mix = 1'b0; rs1 = 32'h0;
        rs2 = 32'h00000053; bs = 2'b00; check_vec("G5", 1, 32'h000000ED);
        rs2 = 32'h00005300; bs = 2'b01; check_vec("G5", 2, 32'h0000ED00);
        rs2 = 32'h00530000; bs = 2'b10; check_vec("G5", 3, 32'h00ED0000);
        rs2 = 32'h53000000; bs = 2'b11; check_vec("G5", 4, 32'hED000000);

        // Group 6: XOR with rs1 (bs=0)
        $display("--- Group 6: XOR with rs1 ---");
        bs = 2'b00;
        mix = 1'b1; rs1 = 32'hDEADBEEF; rs2 = 32'h00000053; check_vec("G6", 1, 32'hF240532E);
        mix = 1'b0; rs1 = 32'hFFFFFFFF; rs2 = 32'h00000053; check_vec("G6", 2, 32'hFFFFFF12);
        mix = 1'b1; rs1 = 32'h2CEDEDC1; rs2 = 32'h00000053; check_vec("G6", 3, 32'h00000000);

        // Summary
        $display("");
        if (fail_count == 0) begin
            $display("PASS: All %0d tests passed.", pass_count);
            $finish;
        end else begin
            $display("FAIL: %0d/%0d tests failed.", fail_count, pass_count + fail_count);
            $fatal(1, "Test suite FAILED");
        end
    end

endmodule
