//
//  CompositeNoise.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

constant int permutations[256] = {
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
};

// Hash function to get a value from the permutation table
inline int hash(int x) {
    return permutations[x & 255];
}

// Linear interpolation function
inline float lerp(float t, float a, float b) {
    return a + t * (b - a);
}

// Fade function to smooth the results
inline float fade(float t) {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

// Gradient function
inline float grad(int hash, float x, float y, float z) {
    int h = hash & 15;
    float u = h < 8 ? x : y;
    float v = h < 4 ? y : h == 12 || h == 14 ? x : z;
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
}

static float perlinNoise(float3 p) {
    int X = (int)floor(p.x) & 255;
    int Y = (int)floor(p.y) & 255;
    int Z = (int)floor(p.z) & 255;
    
    float x = p.x - floor(p.x);
    float y = p.y - floor(p.y);
    float z = p.z - floor(p.z);
    
    float u = fade(x);
    float v = fade(y);
    float w = fade(z);
    
    int A = hash(X) + Y;
    int AA = hash(A) + Z;
    int AB = hash(A + 1) + Z;
    int B = hash(X + 1) + Y;
    int BA = hash(B) + Z;
    int BB = hash(B + 1) + Z;
    
    return lerp(w, lerp(v, lerp(u, grad(hash(AA), x, y, z),
                                grad(hash(BA), x - 1, y, z)),
                        lerp(u, grad(hash(AB), x, y - 1, z),
                             grad(hash(BB), x - 1, y - 1, z))),
                lerp(v, lerp(u, grad(hash(AA + 1), x, y, z - 1),
                             grad(hash(BA + 1), x - 1, y, z - 1)),
                     lerp(u, grad(hash(AB + 1), x, y - 1, z - 1),
                          grad(hash(BB + 1), x - 1, y - 1, z - 1))));
}

extern "C" float4 FractalNoise(coreimage::sample_t sample, float frequency, float amplitude, int octaves, float lacunarity, float offset, coreimage::destination dest) {
    float2 uv = dest.coord();
    uv.x = fract(uv.x + offset);
    float noise = 0.0;
    float maxAmplitude = 0.0;
    float currentFrequency = frequency;
    float currentAmplitude = amplitude;

    for (int i = 0; i < octaves; i++) {
        noise += (currentAmplitude * perlinNoise(float3(uv, 0) * currentFrequency));
        maxAmplitude += currentAmplitude;
        currentFrequency *= lacunarity;
    }

    noise /= maxAmplitude;

    return float4(noise, noise, noise, 1.0);
}
