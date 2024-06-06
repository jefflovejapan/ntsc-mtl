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
 texture2d<half, access::read_write> filteredSampleTexture [[texture(2)]],
 constant half &num0 [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 result = zTex0.read(gid) + (num0 * inputTexture.read(gid));
    half3 yiq = result.xyz;
    yiq = clampYIQ(yiq);
    half4 final = half4(yiq, 1.0);
    filteredSampleTexture.write(final, gid);
}
