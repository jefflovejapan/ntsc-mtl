//
//  Noise.metal
//
//
//  Created by Jeffrey Blagdon on 2024-07-11.
//

#include <metal_stdlib>
using namespace metal;

kernel void noise
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> noise [[texture(1)]],
 texture2d<half, access::write> output [[texture(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inPx = input.read(gid);
    half noiseVal = noise.read(gid).x - 0.5h; // +/- 0.5
    inPx.x += noiseVal;
    output.write(inPx, gid);
}
