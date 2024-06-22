//
//  BlackLineBorder.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

#include <metal_stdlib>
using namespace metal;

kernel void blackLineBorder
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant float &borderPct [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    uint maxXForBlack = uint(borderPct * float(inputTexture.get_width()));
    half4 px = inputTexture.read(gid);
    if (gid.x < maxXForBlack) {
        px.xyz = half3(0.h, 0.h, 0.h);
    }
    outputTexture.write(px, gid);
}

