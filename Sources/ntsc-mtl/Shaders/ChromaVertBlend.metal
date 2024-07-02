//
//  ChromaVertBlend.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void chromaVertBlend
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::write> output [[texture(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 thisPx = input.read(gid);
    half4 pxAbove = input.read(uint2(gid.x, gid.y + 2));
    half4 final = mix(thisPx, pxAbove, 0.5);
    output.write(final, gid);
}



