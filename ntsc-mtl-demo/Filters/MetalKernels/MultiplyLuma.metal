//
//  MultiplyLuma.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void multiplyLuma
(
 texture2d<half, access::read> textureA [[texture(0)]],
 texture2d<half, access::read> textureB [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &intensity,
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(textureA.get_width(), textureB.get_width());
//    half minHeight = min(textureA.get_height(), textureB.get_height());
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 sampleA = textureA.read(gid);
    half4 sampleB = textureB.read(gid);
    half4 result = sampleA;
    result.x += (sampleB.x * 0.25 * intensity);
    half3 yiq = result.xyz;
//    yiq = clampYIQ(yiq);
    half4 yiqa = half4(yiq, 1.0);
    outputTexture.write(yiqa, gid);
}

