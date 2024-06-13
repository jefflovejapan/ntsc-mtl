//
//  Xoshiro256PlusPlus.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-13.
//

// PRNG.metal
#include <metal_stdlib>
using namespace metal;

// Utility functions for bitwise operations and conversions
inline uint32_t RotL(uint32_t x, int s) {
    return (x << s) | (x >> (32 - s));
}

inline uint64_t RotL(uint64_t x, int s) {
    return (x << s) | (x >> (64 - s));
}

inline float FloatFromBits(uint32_t i) {
    return (i >> 8) * 0x1.0p-24f;
}

// SplitMix64 PRNG
struct SplitMix64 {
    uint64_t state;
    
    SplitMix64(uint64_t seed) {
        state = seed;
    }
    
    uint64_t next() {
        uint64_t z = (state += 0x9e3779b97f4a7c15);
        z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) * 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }
    
    void generateSeedSequence(thread uint64_t* seeds, uint32_t N) {
        for (uint32_t i = 0; i < N; ++i) {
            seeds[i] = next();
        }
    }
};

// Xoshiro256Plus PRNG
struct Xoshiro256Plus {
    uint64_t state[4];
    
    Xoshiro256Plus(uint64_t seed) {
        SplitMix64 sm(seed);
        sm.generateSeedSequence(state, 4);
    }
    
    uint64_t next() {
        uint64_t result = state[0] + state[3];
        uint64_t t = state[1] << 17;
        
        state[2] ^= state[0];
        state[3] ^= state[1];
        state[1] ^= state[2];
        state[0] ^= state[3];
        state[2] ^= t;
        state[3] = RotL(state[3], 45);
        
        return result;
    }
    
    void jump() {
        const uint64_t JUMP[4] = { 0x180ec6d33cfd0abaULL, 0xd5a61266f0c9392cULL, 0xa9582618e03fc9aaULL, 0x39abdc4529b1661cULL };
        
        uint64_t s0 = 0;
        uint64_t s1 = 0;
        uint64_t s2 = 0;
        uint64_t s3 = 0;
        
        for (uint32_t i = 0; i < 4; ++i) {
            for (int b = 0; b < 64; ++b) {
                if (JUMP[i] & (1ULL << b)) {
                    s0 ^= state[0];
                    s1 ^= state[1];
                    s2 ^= state[2];
                    s3 ^= state[3];
                }
                next();
            }
        }
        
        state[0] = s0;
        state[1] = s1;
        state[2] = s2;
        state[3] = s3;
    }
    
    void longJump() {
        const uint64_t LONG_JUMP[4] = { 0x76e15d3efefdcbbfULL, 0xc5004e441c522fb3ULL, 0x77710069854ee241ULL, 0x39109bb02acbe635ULL };
        
        uint64_t s0 = 0;
        uint64_t s1 = 0;
        uint64_t s2 = 0;
        uint64_t s3 = 0;
        
        for (uint32_t i = 0; i < 4; ++i) {
            for (int b = 0; b < 64; ++b) {
                if (LONG_JUMP[i] & (1ULL << b)) {
                    s0 ^= state[0];
                    s1 ^= state[1];
                    s2 ^= state[2];
                    s3 ^= state[3];
                }
                next();
            }
        }
        
        state[0] = s0;
        state[1] = s1;
        state[2] = s2;
        state[3] = s3;
    }
};
