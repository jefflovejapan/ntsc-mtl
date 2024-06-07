//
//  IIRFinalImage.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void iirFinalImage
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> filteredSampleTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &scale [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(inputTexture.get_width(), filteredImageTexture.get_width());
//    half minHeight = min(inputTexture.get_height(), filteredImageTexture.get_height());
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 currentSample = inputTexture.read(gid);
    half4 filteredSample = filteredSampleTexture.read(gid);
    half4 combined = ((filteredSample - currentSample) * scale) + currentSample;
    half3 yiq = combined.xyz;
    yiq = clampYIQ(yiq);
    half4 final = half4(yiq, 1.0);
    outputTexture.write(final, gid);
}

