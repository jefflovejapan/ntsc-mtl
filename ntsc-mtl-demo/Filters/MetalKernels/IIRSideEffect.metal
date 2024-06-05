//
//  IIRSideEffect.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void iirSideEffect
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read_write> z [[texture(1)]],
 texture2d<half, access::read> zPlusOne [[texture(2)]],
 texture2d<half, access::read> filteredSampleTexture [[texture(3)]],
 constant half &num [[buffer(0)]],
 constant half &denom [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 currentSample = inputTexture.read(gid);
    half4 sideEffected = zPlusOne.read(gid);
    half4 filteredSample = filteredSampleTexture.read(gid);
    half4 result = sideEffected + (num * currentSample) - (denom * filteredSample);
    half3 yiq = result.xyz;
    yiq = clampYIQ(yiq);
    half4 final = half4(yiq, 1.0);
    z.write(final, gid);
}
