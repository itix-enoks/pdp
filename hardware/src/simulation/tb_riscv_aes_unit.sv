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
    integer g7_fails;
    integer i;
    logic [7:0] sbox_ref [0:255];

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

        // FIPS-197 Table 4 forward SBox
        sbox_ref['h00]=8'h63; sbox_ref['h01]=8'h7c; sbox_ref['h02]=8'h77; sbox_ref['h03]=8'h7b;
        sbox_ref['h04]=8'hf2; sbox_ref['h05]=8'h6b; sbox_ref['h06]=8'h6f; sbox_ref['h07]=8'hc5;
        sbox_ref['h08]=8'h30; sbox_ref['h09]=8'h01; sbox_ref['h0a]=8'h67; sbox_ref['h0b]=8'h2b;
        sbox_ref['h0c]=8'hfe; sbox_ref['h0d]=8'hd7; sbox_ref['h0e]=8'hab; sbox_ref['h0f]=8'h76;
        sbox_ref['h10]=8'hca; sbox_ref['h11]=8'h82; sbox_ref['h12]=8'hc9; sbox_ref['h13]=8'h7d;
        sbox_ref['h14]=8'hfa; sbox_ref['h15]=8'h59; sbox_ref['h16]=8'h47; sbox_ref['h17]=8'hf0;
        sbox_ref['h18]=8'had; sbox_ref['h19]=8'hd4; sbox_ref['h1a]=8'ha2; sbox_ref['h1b]=8'haf;
        sbox_ref['h1c]=8'h9c; sbox_ref['h1d]=8'ha4; sbox_ref['h1e]=8'h72; sbox_ref['h1f]=8'hc0;
        sbox_ref['h20]=8'hb7; sbox_ref['h21]=8'hfd; sbox_ref['h22]=8'h93; sbox_ref['h23]=8'h26;
        sbox_ref['h24]=8'h36; sbox_ref['h25]=8'h3f; sbox_ref['h26]=8'hf7; sbox_ref['h27]=8'hcc;
        sbox_ref['h28]=8'h34; sbox_ref['h29]=8'ha5; sbox_ref['h2a]=8'he5; sbox_ref['h2b]=8'hf1;
        sbox_ref['h2c]=8'h71; sbox_ref['h2d]=8'hd8; sbox_ref['h2e]=8'h31; sbox_ref['h2f]=8'h15;
        sbox_ref['h30]=8'h04; sbox_ref['h31]=8'hc7; sbox_ref['h32]=8'h23; sbox_ref['h33]=8'hc3;
        sbox_ref['h34]=8'h18; sbox_ref['h35]=8'h96; sbox_ref['h36]=8'h05; sbox_ref['h37]=8'h9a;
        sbox_ref['h38]=8'h07; sbox_ref['h39]=8'h12; sbox_ref['h3a]=8'h80; sbox_ref['h3b]=8'he2;
        sbox_ref['h3c]=8'heb; sbox_ref['h3d]=8'h27; sbox_ref['h3e]=8'hb2; sbox_ref['h3f]=8'h75;
        sbox_ref['h40]=8'h09; sbox_ref['h41]=8'h83; sbox_ref['h42]=8'h2c; sbox_ref['h43]=8'h1a;
        sbox_ref['h44]=8'h1b; sbox_ref['h45]=8'h6e; sbox_ref['h46]=8'h5a; sbox_ref['h47]=8'ha0;
        sbox_ref['h48]=8'h52; sbox_ref['h49]=8'h3b; sbox_ref['h4a]=8'hd6; sbox_ref['h4b]=8'hb3;
        sbox_ref['h4c]=8'h29; sbox_ref['h4d]=8'he3; sbox_ref['h4e]=8'h2f; sbox_ref['h4f]=8'h84;
        sbox_ref['h50]=8'h53; sbox_ref['h51]=8'hd1; sbox_ref['h52]=8'h00; sbox_ref['h53]=8'hed;
        sbox_ref['h54]=8'h20; sbox_ref['h55]=8'hfc; sbox_ref['h56]=8'hb1; sbox_ref['h57]=8'h5b;
        sbox_ref['h58]=8'h6a; sbox_ref['h59]=8'hcb; sbox_ref['h5a]=8'hbe; sbox_ref['h5b]=8'h39;
        sbox_ref['h5c]=8'h4a; sbox_ref['h5d]=8'h4c; sbox_ref['h5e]=8'h58; sbox_ref['h5f]=8'hcf;
        sbox_ref['h60]=8'hd0; sbox_ref['h61]=8'hef; sbox_ref['h62]=8'haa; sbox_ref['h63]=8'hfb;
        sbox_ref['h64]=8'h43; sbox_ref['h65]=8'h4d; sbox_ref['h66]=8'h33; sbox_ref['h67]=8'h85;
        sbox_ref['h68]=8'h45; sbox_ref['h69]=8'hf9; sbox_ref['h6a]=8'h02; sbox_ref['h6b]=8'h7f;
        sbox_ref['h6c]=8'h50; sbox_ref['h6d]=8'h3c; sbox_ref['h6e]=8'h9f; sbox_ref['h6f]=8'ha8;
        sbox_ref['h70]=8'h51; sbox_ref['h71]=8'ha3; sbox_ref['h72]=8'h40; sbox_ref['h73]=8'h8f;
        sbox_ref['h74]=8'h92; sbox_ref['h75]=8'h9d; sbox_ref['h76]=8'h38; sbox_ref['h77]=8'hf5;
        sbox_ref['h78]=8'hbc; sbox_ref['h79]=8'hb6; sbox_ref['h7a]=8'hda; sbox_ref['h7b]=8'h21;
        sbox_ref['h7c]=8'h10; sbox_ref['h7d]=8'hff; sbox_ref['h7e]=8'hf3; sbox_ref['h7f]=8'hd2;
        sbox_ref['h80]=8'hcd; sbox_ref['h81]=8'h0c; sbox_ref['h82]=8'h13; sbox_ref['h83]=8'hec;
        sbox_ref['h84]=8'h5f; sbox_ref['h85]=8'h97; sbox_ref['h86]=8'h44; sbox_ref['h87]=8'h17;
        sbox_ref['h88]=8'hc4; sbox_ref['h89]=8'ha7; sbox_ref['h8a]=8'h7e; sbox_ref['h8b]=8'h3d;
        sbox_ref['h8c]=8'h64; sbox_ref['h8d]=8'h5d; sbox_ref['h8e]=8'h19; sbox_ref['h8f]=8'h73;
        sbox_ref['h90]=8'h60; sbox_ref['h91]=8'h81; sbox_ref['h92]=8'h4f; sbox_ref['h93]=8'hdc;
        sbox_ref['h94]=8'h22; sbox_ref['h95]=8'h2a; sbox_ref['h96]=8'h90; sbox_ref['h97]=8'h88;
        sbox_ref['h98]=8'h46; sbox_ref['h99]=8'hee; sbox_ref['h9a]=8'hb8; sbox_ref['h9b]=8'h14;
        sbox_ref['h9c]=8'hde; sbox_ref['h9d]=8'h5e; sbox_ref['h9e]=8'h0b; sbox_ref['h9f]=8'hdb;
        sbox_ref['ha0]=8'he0; sbox_ref['ha1]=8'h32; sbox_ref['ha2]=8'h3a; sbox_ref['ha3]=8'h0a;
        sbox_ref['ha4]=8'h49; sbox_ref['ha5]=8'h06; sbox_ref['ha6]=8'h24; sbox_ref['ha7]=8'h5c;
        sbox_ref['ha8]=8'hc2; sbox_ref['ha9]=8'hd3; sbox_ref['haa]=8'hac; sbox_ref['hab]=8'h62;
        sbox_ref['hac]=8'h91; sbox_ref['had]=8'h95; sbox_ref['hae]=8'he4; sbox_ref['haf]=8'h79;
        sbox_ref['hb0]=8'he7; sbox_ref['hb1]=8'hc8; sbox_ref['hb2]=8'h37; sbox_ref['hb3]=8'h6d;
        sbox_ref['hb4]=8'h8d; sbox_ref['hb5]=8'hd5; sbox_ref['hb6]=8'h4e; sbox_ref['hb7]=8'ha9;
        sbox_ref['hb8]=8'h6c; sbox_ref['hb9]=8'h56; sbox_ref['hba]=8'hf4; sbox_ref['hbb]=8'hea;
        sbox_ref['hbc]=8'h65; sbox_ref['hbd]=8'h7a; sbox_ref['hbe]=8'hae; sbox_ref['hbf]=8'h08;
        sbox_ref['hc0]=8'hba; sbox_ref['hc1]=8'h78; sbox_ref['hc2]=8'h25; sbox_ref['hc3]=8'h2e;
        sbox_ref['hc4]=8'h1c; sbox_ref['hc5]=8'ha6; sbox_ref['hc6]=8'hb4; sbox_ref['hc7]=8'hc6;
        sbox_ref['hc8]=8'he8; sbox_ref['hc9]=8'hdd; sbox_ref['hca]=8'h74; sbox_ref['hcb]=8'h1f;
        sbox_ref['hcc]=8'h4b; sbox_ref['hcd]=8'hbd; sbox_ref['hce]=8'h8b; sbox_ref['hcf]=8'h8a;
        sbox_ref['hd0]=8'h70; sbox_ref['hd1]=8'h3e; sbox_ref['hd2]=8'hb5; sbox_ref['hd3]=8'h66;
        sbox_ref['hd4]=8'h48; sbox_ref['hd5]=8'h03; sbox_ref['hd6]=8'hf6; sbox_ref['hd7]=8'h0e;
        sbox_ref['hd8]=8'h61; sbox_ref['hd9]=8'h35; sbox_ref['hda]=8'h57; sbox_ref['hdb]=8'hb9;
        sbox_ref['hdc]=8'h86; sbox_ref['hdd]=8'hc1; sbox_ref['hde]=8'h1d; sbox_ref['hdf]=8'h9e;
        sbox_ref['he0]=8'he1; sbox_ref['he1]=8'hf8; sbox_ref['he2]=8'h98; sbox_ref['he3]=8'h11;
        sbox_ref['he4]=8'h69; sbox_ref['he5]=8'hd9; sbox_ref['he6]=8'h8e; sbox_ref['he7]=8'h94;
        sbox_ref['he8]=8'h9b; sbox_ref['he9]=8'h1e; sbox_ref['hea]=8'h87; sbox_ref['heb]=8'he9;
        sbox_ref['hec]=8'hce; sbox_ref['hed]=8'h55; sbox_ref['hee]=8'h28; sbox_ref['hef]=8'hdf;
        sbox_ref['hf0]=8'h8c; sbox_ref['hf1]=8'ha1; sbox_ref['hf2]=8'h89; sbox_ref['hf3]=8'h0d;
        sbox_ref['hf4]=8'hbf; sbox_ref['hf5]=8'he6; sbox_ref['hf6]=8'h42; sbox_ref['hf7]=8'h68;
        sbox_ref['hf8]=8'h41; sbox_ref['hf9]=8'h99; sbox_ref['hfa]=8'h2d; sbox_ref['hfb]=8'h0f;
        sbox_ref['hfc]=8'hb0; sbox_ref['hfd]=8'h54; sbox_ref['hfe]=8'hbb; sbox_ref['hff]=8'h16;

        // SBox spot checks (mix=0, bs=0, rs1=0)
        $display("--- Group 1: SBox spot checks ---");
        mix = 1'b0; bs = 2'b00; rs1 = 32'h0;
        rs2 = 32'h00000000; check_vec("G1", 1, 32'h00000063); // SBox[0x00]=0x63
        rs2 = 32'h00000001; check_vec("G1", 2, 32'h0000007C); // SBox[0x01]=0x7C
        rs2 = 32'h00000010; check_vec("G1", 3, 32'h000000CA); // SBox[0x10]=0xCA
        rs2 = 32'h00000053; check_vec("G1", 4, 32'h000000ED); // SBox[0x53]=0xED
        rs2 = 32'h00000052; check_vec("G1", 5, 32'h00000000); // SBox[0x52]=0x00
        rs2 = 32'h000000FF; check_vec("G1", 6, 32'h00000016); // SBox[0xFF]=0x16

        // byte_select at all bs (mix=0, rs1=0, rs2=0xAABBCCDD)
        $display("--- Group 2: byte_select ---");
        mix = 1'b0; rs1 = 32'h0; rs2 = 32'hAABBCCDD;
        bs = 2'b00; check_vec("G2", 1, 32'h000000C1); // SBox[0xDD]=0xC1
        bs = 2'b01; check_vec("G2", 2, 32'h00004B00); // SBox[0xCC]=0x4B, rotL8
        bs = 2'b10; check_vec("G2", 3, 32'h00EA0000); // SBox[0xBB]=0xEA, rotL16
        bs = 2'b11; check_vec("G2", 4, 32'hAC000000); // SBox[0xAA]=0xAC, rotL24

        // aes32esmi MixColumns math (mix=1, bs=0, rs1=0)
        $display("--- Group 3: MixColumns math ---");
        mix = 1'b1; bs = 2'b00; rs1 = 32'h0;
        rs2 = 32'h00000000; check_vec("G3", 1, 32'hA56363C6); // so=0x63,xt2=0xC6,xt3=0xA5
        rs2 = 32'h00000053; check_vec("G3", 2, 32'h2CEDEDC1); // so=0xED,xt2=0xC1,xt3=0x2C
        rs2 = 32'h000000FF; check_vec("G3", 3, 32'h3A16162C); // so=0x16,xt2=0x2C,xt3=0x3A

        // rotation (mix=1, rs1=0, byte 0x53 at bs)
        $display("--- Group 4: rotation ---");
        mix = 1'b1; rs1 = 32'h0;
        rs2 = 32'h00000053; bs = 2'b00; check_vec("G4", 1, 32'h2CEDEDC1);
        rs2 = 32'h00005300; bs = 2'b01; check_vec("G4", 2, 32'hEDEDC12C);
        rs2 = 32'h00530000; bs = 2'b10; check_vec("G4", 3, 32'hEDC12CED);
        rs2 = 32'h53000000; bs = 2'b11; check_vec("G4", 4, 32'hC12CEDED);

        // aes32esi placement (mix=0, rs1=0, byte 0x53 at bs)
        $display("--- Group 5: esi placement ---");
        mix = 1'b0; rs1 = 32'h0;
        rs2 = 32'h00000053; bs = 2'b00; check_vec("G5", 1, 32'h000000ED);
        rs2 = 32'h00005300; bs = 2'b01; check_vec("G5", 2, 32'h0000ED00);
        rs2 = 32'h00530000; bs = 2'b10; check_vec("G5", 3, 32'h00ED0000);
        rs2 = 32'h53000000; bs = 2'b11; check_vec("G5", 4, 32'hED000000);

        // XOR with rs1 (bs=0)
        $display("--- Group 6: XOR with rs1 ---");
        bs = 2'b00;
        mix = 1'b1; rs1 = 32'hDEADBEEF; rs2 = 32'h00000053; check_vec("G6", 1, 32'hF240532E);
        mix = 1'b0; rs1 = 32'hFFFFFFFF; rs2 = 32'h00000053; check_vec("G6", 2, 32'hFFFFFF12);
        mix = 1'b1; rs1 = 32'h2CEDEDC1; rs2 = 32'h00000053; check_vec("G6", 3, 32'h00000000);

        // exhaustive SBox sweep (all 256 input bytes)
        $display("--- Group 7: SBox sweep ---");
        g7_fails = 0;
        mix = 1'b0; bs = 2'b00; rs1 = 32'h0;
        for (i = 0; i < 256; i = i + 1) begin
            rs2 = {24'h0, i[7:0]};
            #1;
            if (result[7:0] !== sbox_ref[i]) begin
                $display("  FAIL [G7-%0d]: SBox[%02X] got %02X exp %02X",
                         i, i[7:0], result[7:0], sbox_ref[i]);
                g7_fails = g7_fails + 1;
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end
        if (g7_fails == 0)
            $display("  pass [G7]: 256 SBox entries verified");

        // Summary
        $display("");
        if (fail_count == 0) begin
            $display(" PASS:  All %0d tests passed.", pass_count);
            $finish;
        end else begin
            $display("FAIL: %0d/%0d tests failed.", fail_count, pass_count + fail_count);
            $fatal(1, "Test suite FAILED");
        end
    end

endmodule
