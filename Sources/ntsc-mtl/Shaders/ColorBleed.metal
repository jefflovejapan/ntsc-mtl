//
//  ColorBleed.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

#include <metal_stdlib>
using namespace metal;

kernel void colorBleed
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant uint &vertShift [[buffer(0)]],
 constant uint &horizShift [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
) {
    uint2 modLoc = uint2(gid.x - vertShift, gid.y - horizShift);
    half4 modPx = inputTexture.read(modLoc);
    half4 px = inputTexture.read(gid);
    half4 final = half4(px.x, modPx.yz, px.w);
    outputTexture.write(final, gid);
}
