//
//  IIRInitialCondition.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void iirInitialCondition
(
 texture2d<half, access::read> initialConditionTex [[texture(0)]],
 texture2d<half, access::read> zTex0 [[texture(1)]],
 texture2d<half, access::write> zTexToFill [[texture(2)]],
 constant float &aSum [[buffer(0)]],
 constant float &cSum [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(textureToFill.get_width(), sideEffectedTexture.get_width());
//    half minHeight = min(textureToFill.get_height(), sideEffectedTexture.get_height());
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 initialCondition = initialConditionTex.read(gid);
    half4 z0 = zTex0.read(gid);
    half4 output = ((aSum * z0) - cSum) * initialCondition;
    half3 yiq = output.xyz;
//    yiq = clampYIQ(yiq);
    half4 final = half4(yiq, 1.0);
    zTexToFill.write(final, gid);
}
