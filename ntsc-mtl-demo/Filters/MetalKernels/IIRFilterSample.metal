//
//  IIRFilterSample.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void iirFilterSample
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> zTex0 [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant float &num0 [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(inputTexture.get_width(), min(zTex0.get_width(), filteredSampleTexture.get_width()));
//    half minHeight = min(inputTexture.get_height(), min(zTex0.get_height(), filteredSampleTexture.get_height()));
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 result = zTex0.read(gid) + (num0 * inputTexture.read(gid));
    half3 yiq = result.xyz;
//    yiq = clampYIQ(yiq);
    half4 final = half4(yiq, 1.0);
    outputTexture.write(final, gid);
}
