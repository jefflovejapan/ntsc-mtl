//
//  vhsEdgeWave.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-23.
//

#include <metal_stdlib>
using namespace metal;

kernel void vhsEdgeWave
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> randomLowpassed [[texture(1)]],
 texture2d<half, access::write> out [[texture(2)]],
 constant uint &edgeWave [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    uint rnd = uint(randomLowpassed.read(uint2(0, gid.y)).x);
    half4 px = input.read(uint2(gid.x - rnd, gid.y));
    out.write(px, gid);
}
