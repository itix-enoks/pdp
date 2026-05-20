#include <stdio.h>
#include <stdint.h>
#include <string.h>

// ===========================================================================
// RISC-V Zkne AES inline-asm helpers
// ===========================================================================
//
// We emit aes32esmi / aes32esi using the GNU `.insn r` directive so the
// toolchain does NOT need to know the Zkne mnemonics or be built with a
// matching -march. The decoder + ALU integration in the riscy core handles
// the rest.
//
// Encoding (RISC-V K-extension scalar crypto, Zkne):
//   aes32esmi rd, rs1, rs2, bs : opcode=OP (0x33), funct3=000,
//                                funct7 = {bs[1:0], 5'b10011}
//   aes32esi  rd, rs1, rs2, bs : opcode=OP (0x33), funct3=000,
//                                funct7 = {bs[1:0], 5'b10001}
//
// We use the read-modify-write form rd==rs1==acc to drive the canonical
// "accumulator chain" pattern: one accumulator gathers four AES contributions
// (one per source byte) to produce one output column.
//
// `bs_const` MUST be a compile-time literal in [0,3]. The `"i"` constraint
// requires this, since funct7 is part of the instruction word.

#define AES32ESMI(acc, src, bs_const)                                    \
    asm volatile (".insn r 0x33, 0, %2, %0, %0, %1"                      \
                  : "+r"(acc)                                            \
                  : "r"(src),                                            \
                    "i"(0x13 | ((bs_const) << 5)))

#define AES32ESI(acc, src, bs_const)                                     \
    asm volatile (".insn r 0x33, 0, %2, %0, %0, %1"                      \
                  : "+r"(acc)                                            \
                  : "r"(src),                                            \
                    "i"(0x11 | ((bs_const) << 5)))

// Little-endian byte<->word packing for the AES state and round keys.
// round_keys[] is uint8_t (possibly unaligned), so we go byte-by-byte
// rather than risking an unaligned 32-bit load on RV32.
static inline uint32_t pack_le32(const uint8_t *p) {
    return  (uint32_t)p[0]
         | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[3] << 24);
}

static inline void unpack_le32(uint8_t *p, uint32_t w) {
    p[0] = (uint8_t)(w);
    p[1] = (uint8_t)(w >> 8);
    p[2] = (uint8_t)(w >> 16);
    p[3] = (uint8_t)(w >> 24);
}

// S-box for SubBytes (precomputed substitution table)
static const uint8_t sbox[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};

// Round constants for key expansion
static const uint8_t rcon[10] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
};

// Key expansion function
void expand_key(uint8_t *key, uint8_t *round_keys) {
    int i;
    for (i = 0; i < 16; i++) {
        round_keys[i] = key[i];
    }
    for (i = 16; i < 176; i += 4) {
        uint8_t temp[4];
        temp[0] = round_keys[i - 4];
        temp[1] = round_keys[i - 3];
        temp[2] = round_keys[i - 2];
        temp[3] = round_keys[i - 1];
        if (i % 16 == 0) {
            uint8_t t = temp[0];
            temp[0] = sbox[temp[1]];
            temp[1] = sbox[temp[2]];
            temp[2] = sbox[temp[3]];
            temp[3] = sbox[t];
            temp[0] ^= rcon[(i / 16) - 1];
        }
        round_keys[i]     = round_keys[i - 16] ^ temp[0];
        round_keys[i + 1] = round_keys[i - 15] ^ temp[1];
        round_keys[i + 2] = round_keys[i - 14] ^ temp[2];
        round_keys[i + 3] = round_keys[i - 13] ^ temp[3];
    }
}

// SubBytes transformation
void sub_bytes(uint8_t *state) {
    for (int i = 0; i < 16; i++) {
        state[i] = sbox[state[i]];
    }
}

// ShiftRows transformation
void shift_rows(uint8_t *state) {
    uint8_t temp;
    temp = state[1]; state[1] = state[5]; state[5] = state[9]; state[9] = state[13]; state[13] = temp;
    temp = state[2]; state[2] = state[10]; state[10] = temp;
    temp = state[6]; state[6] = state[14]; state[14] = temp;
    temp = state[15]; state[15] = state[11]; state[11] = state[7]; state[7] = state[3]; state[3] = temp;
}

// GF(2^8) multiplication
uint8_t gf_mult(uint8_t a, uint8_t b) {
    uint8_t p = 0;
    for (int i = 0; i < 8; i++) {
        if (b & 1) p ^= a;
        uint8_t hi_bit = a & 0x80;
        a <<= 1;
        if (hi_bit) a ^= 0x1b; // Reduce modulo 0x11b
        b >>= 1;
    }
    return p;
}

// MixColumns transformation
void mix_columns(uint8_t *state) {
    uint8_t temp[16];
    for (int i = 0; i < 4; i++) {
        int idx = i * 4;
        temp[idx]     = gf_mult(0x02, state[idx]) ^ gf_mult(0x03, state[idx + 1]) ^ state[idx + 2] ^ state[idx + 3];
        temp[idx + 1] = state[idx] ^ gf_mult(0x02, state[idx + 1]) ^ gf_mult(0x03, state[idx + 2]) ^ state[idx + 3];
        temp[idx + 2] = state[idx] ^ state[idx + 1] ^ gf_mult(0x02, state[idx + 2]) ^ gf_mult(0x03, state[idx + 3]);
        temp[idx + 3] = gf_mult(0x03, state[idx]) ^ state[idx + 1] ^ state[idx + 2] ^ gf_mult(0x02, state[idx + 3]);
    }
    for (int i = 0; i < 16; i++) {
        state[i] = temp[i];
    }
}

// AddRoundKey transformation
void add_round_key(uint8_t *state, uint8_t *round_key) {
    for (int i = 0; i < 16; i++) {
        state[i] ^= round_key[i];
    }
}

// Single block AES-128 encryption — Zkne (aes32esmi / aes32esi) accelerated.
//
// State is held in four 32-bit words s[0..3], one per AES column, with row 0
// in the LSB and row 3 in the MSB (little-endian column packing).
//
// For each round, the four output columns are each built as an accumulator
// chain starting from the round-key word for that column. ShiftRows is
// folded into the source-word selection: byte `r` of output column `j`
// comes from byte `r` of input column `(j+r) & 3`. Because aes32es{,m}i
// reads byte `bs` of rs2, we set bs = r and pick rs2 = s[(j+r) & 3].
void aes128_encrypt_block(uint8_t *plaintext, uint8_t *round_keys, uint8_t *ciphertext) {
    uint32_t s0, s1, s2, s3;
    uint32_t t0, t1, t2, t3;
    uint32_t rk0, rk1, rk2, rk3;

    // Load plaintext (4 columns, little-endian).
    s0 = pack_le32(&plaintext[0]);
    s1 = pack_le32(&plaintext[4]);
    s2 = pack_le32(&plaintext[8]);
    s3 = pack_le32(&plaintext[12]);

    // Initial AddRoundKey (round 0).
    rk0 = pack_le32(&round_keys[0]);
    rk1 = pack_le32(&round_keys[4]);
    rk2 = pack_le32(&round_keys[8]);
    rk3 = pack_le32(&round_keys[12]);
    s0 ^= rk0; s1 ^= rk1; s2 ^= rk2; s3 ^= rk3;

    // Main rounds 1..9: SubBytes + ShiftRows + MixColumns + AddRoundKey,
    // fused per-column via aes32esmi.
    for (int round = 1; round < 10; round++) {
        const uint8_t *rkp = &round_keys[round * 16];
        t0 = pack_le32(&rkp[0]);
        t1 = pack_le32(&rkp[4]);
        t2 = pack_le32(&rkp[8]);
        t3 = pack_le32(&rkp[12]);

        // Output column 0: source columns (0,1,2,3) for rows (0,1,2,3).
        AES32ESMI(t0, s0, 0);
        AES32ESMI(t0, s1, 1);
        AES32ESMI(t0, s2, 2);
        AES32ESMI(t0, s3, 3);
        // Output column 1: source columns (1,2,3,0).
        AES32ESMI(t1, s1, 0);
        AES32ESMI(t1, s2, 1);
        AES32ESMI(t1, s3, 2);
        AES32ESMI(t1, s0, 3);
        // Output column 2: source columns (2,3,0,1).
        AES32ESMI(t2, s2, 0);
        AES32ESMI(t2, s3, 1);
        AES32ESMI(t2, s0, 2);
        AES32ESMI(t2, s1, 3);
        // Output column 3: source columns (3,0,1,2).
        AES32ESMI(t3, s3, 0);
        AES32ESMI(t3, s0, 1);
        AES32ESMI(t3, s1, 2);
        AES32ESMI(t3, s2, 3);

        s0 = t0; s1 = t1; s2 = t2; s3 = t3;
    }

    // Final round (10): SubBytes + ShiftRows + AddRoundKey (no MixColumns),
    // fused per-column via aes32esi.
    {
        const uint8_t *rkp = &round_keys[10 * 16];
        t0 = pack_le32(&rkp[0]);
        t1 = pack_le32(&rkp[4]);
        t2 = pack_le32(&rkp[8]);
        t3 = pack_le32(&rkp[12]);

        AES32ESI(t0, s0, 0);
        AES32ESI(t0, s1, 1);
        AES32ESI(t0, s2, 2);
        AES32ESI(t0, s3, 3);
        AES32ESI(t1, s1, 0);
        AES32ESI(t1, s2, 1);
        AES32ESI(t1, s3, 2);
        AES32ESI(t1, s0, 3);
        AES32ESI(t2, s2, 0);
        AES32ESI(t2, s3, 1);
        AES32ESI(t2, s0, 2);
        AES32ESI(t2, s1, 3);
        AES32ESI(t3, s3, 0);
        AES32ESI(t3, s0, 1);
        AES32ESI(t3, s1, 2);
        AES32ESI(t3, s2, 3);

        s0 = t0; s1 = t1; s2 = t2; s3 = t3;
    }

    // Store ciphertext (column-major, little-endian — same layout as plaintext).
    unpack_le32(&ciphertext[0],  s0);
    unpack_le32(&ciphertext[4],  s1);
    unpack_le32(&ciphertext[8],  s2);
    unpack_le32(&ciphertext[12], s3);
}

// AES-128 ECB encryption (no padding)
void aes128_ecb_encrypt(uint8_t *plaintext, size_t len, uint8_t *key, uint8_t *ciphertext) {
    if (len % 16 != 0) {
        //printf("Error: Input length must be a multiple of 16 bytes (no padding).\n");
        return;
    }

    uint8_t round_keys[176];
    expand_key(key, round_keys);

    for (size_t i = 0; i < len; i += 16) {
        aes128_encrypt_block(&plaintext[i], round_keys, &ciphertext[i]);
    }
}

void write_to_address(uintptr_t addr, uint32_t value) {
    *(volatile uint32_t *)addr = value;
}

void write_v_to_address(uintptr_t addr, uint8_t vector[16]) {
    uint32_t *vector_word = (uint32_t *)vector;
	for(int i = 0; i < 4; i++) {
        write_to_address(addr + i*0x4, vector_word[i]);
    }
}

int main()
{
	// Plaintext: "Hello, World!000" (16 bytes, 1 block)
    uint8_t plaintext[16] = {
        'H', 'e', 'l', 'l', 'o', ',', ' ', 'W',
        'o', 'r', 'l', 'd', '!', '0', '0', '0'
    };
    // Key: "cese4040password" (16 bytes)
    uint8_t key[16] = {
        'c', 'e', 's', 'e', '4', '0', '4', '0',
        'p', 'a', 's', 's', 'w', 'o', 'r', 'd'
    };
    uint8_t expected_output[16] = {0x14, 0x09, 0xA5, 0xFB, 0x1F, 0xF4, 0x4B, 0x71, 0xBE, 0xAA, 0x25, 0x2E, 0x0F, 0x08, 0xF9, 0xAA};
    uint8_t ciphertext[16];
    size_t len = 16; // Single block

    uintptr_t addr;
    uint32_t value;

    aes128_ecb_encrypt(plaintext, len, key, ciphertext);

    addr = 0x0100000 + 0x2000 + 0x30;
    write_v_to_address(addr, expected_output);
    
    addr = 0x0100000 + 0x2000 + 0x40;
    write_v_to_address(addr, ciphertext);

    // Check if calculated and expected match:
    addr = 0x0100000 + 0x2000 + 0x04;  // Some memory-mapped register or memory location
    value = 0xCAFEBABE; //Assume arrays match initially
    for (int i = 0; i < 16; i++) {
        if (ciphertext[i] != expected_output[i]) {
            value = 0xBAAAAAAD; // Set to false value if there's a mismatch
            break;
        }
    }
    write_to_address(addr, value);

    //END OF TEST WRITE (used to identify when the execution of the C code finished): DO NOT REMOVE!
    addr = 0x0100000 + 0x2000; // SRAM base address is 0x0100000.
    value = 0xDEADBEEF;
    write_to_address(addr, value);

    return 0;
}
