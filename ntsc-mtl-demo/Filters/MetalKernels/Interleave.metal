//
//  Interleave.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-14.
//

#include <metal_stdlib>
using namespace metal;

kernel void interleave
(
 texture2d<half, access::read> textureA [[texture(0)]],
 texture2d<half, access::read> textureB [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 sample;
    if (gid.y % 2 == 0) {
        sample = textureA.read(gid);
    } else {
        sample = textureB.read(gid);
    }
    outputTexture.write(sample, gid);
}
