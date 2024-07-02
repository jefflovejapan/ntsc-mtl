//
//  Mix.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-23.
//

#include <metal_stdlib>
using namespace metal;

kernel void mix
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::write> out [[texture(1)]],
 constant half &min [[buffer(0)]],
 constant half &max [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 px = input.read(gid);
    half4 mixed = mix(min, max, px);
    out.write(mixed, gid);
}
