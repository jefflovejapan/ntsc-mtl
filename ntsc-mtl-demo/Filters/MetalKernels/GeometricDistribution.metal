//
//  GeometricDistribution.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-09.
//

#include <metal_stdlib>
using namespace metal;

kernel void geometricDistribution
(
 texture1d<half, access::write> outTexture [[texture(0)]],
 constant half &probability,
 uint2 gid [[thread_position_in_grid]]
 ) {
    // Parameters for the geometric distribution

    // Initialize random number generator (Xoshiro256++)
    uint seed = gid.x + gid.y * outTexture.get_width();
    uint2 state = uint2(seed, seed);

    // Generate a random number using Xoshiro256++
    uint64_t x = state.x * 0x9E3779B97F4A7C15;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    state.x = (uint)x;
    state.y = (uint)(x >> 32);

    // Generate geometric distribution value
    half u = half(state.x) / half(0xFFFFFFFF);
    half geomValue = log(1.0 - u) / log(1.0 - probability);
    half4 outVal = half4(geomValue);

    // Write the value to the texture
    outTexture.write(outVal, gid.x);
}
