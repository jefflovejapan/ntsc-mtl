//
//  TrackingNoiseShiftRow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-19.
//

#include "ShiftRowInline.metal"
#include <metal_stdlib>
using namespace metal;

kernel void trackingNoiseShiftRow
(
    texture2d<half, access::read> inputTexture [[texture(0)]],
    texture2d<half, access::read> randomTexture [[texture(1)]],
    texture2d<half, access::write> outputTexture [[texture(2)]],
    constant uint &effectHeight [[buffer(0)]],
    constant float &waveIntensity [[buffer(1)]],
    constant float &bandwidthScale [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    half noise = randomTexture.read(uint2(0, gid.y)).x;
    float intensityScale = float(noise) / float(effectHeight);
//    float noisyShift = noise * intensityScale * waveIntensity * 0.25 * bandwidthScale;
    
    shiftRowInline(inputTexture, outputTexture, noisyShift, gid);
}

