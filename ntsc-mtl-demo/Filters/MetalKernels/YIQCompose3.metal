//
//  YIQCompose3.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void yiqCompose3
(
 texture2d<half, access::read> yTexture [[texture(0)]],
 texture2d<half, access::read> iTexture [[texture(1)]],
 texture2d<half, access::read> qTexture [[texture(2)]],
 texture2d<half, access::read_write> outputTexture [[texture(3)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(yTexture.get_width(), min(iTexture.get_width(), qTexture.get_width()));
//    half minHeight = min(yTexture.get_height(), min(iTexture.get_height(), qTexture.get_height()));
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half y = yTexture.read(gid).x;
    half i = iTexture.read(gid).y;
    half q = qTexture.read(gid).z;
    half3 yiq = half3(y, i, q);
    yiq = clampYIQ(yiq);
    half4 result = half4(yiq, 1.0);
    outputTexture.write(result, gid);
}
