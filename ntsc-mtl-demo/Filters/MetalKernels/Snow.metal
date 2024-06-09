//
//  Snow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void snow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &intensity [[buffer(0)]],
 constant half &anisotropy [[buffer(1)]],
 constant half &bandwidthScale [[buffer(2)]],
 constant int &width [[buffer(3)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(randomTexture.get_width(), min(inputTexture.get_width(), outputTexture.get_width()));
//    half minHeight = min(randomTexture.get_height(), min(inputTexture.get_height(), outputTexture.get_height()));
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 inputPixel = inputTexture.read(gid);
    half4 randomPixel = randomTexture.read(gid);
    half rand1 = randomPixel.x;
    half rand2 = randomPixel.y;
    half rand3 = randomPixel.z;
    half logisticFactor = exp((rand1 - intensity) / (intensity * (1.0 - intensity) * (1.0 - anisotropy)));
    half lineSnowIntensity = (anisotropy / (1.0 + logisticFactor)) + (intensity * (1.0 - anisotropy));
    lineSnowIntensity *= 0.125;
    lineSnowIntensity = clamp(lineSnowIntensity, half(0.0), half(1.0));
    if (lineSnowIntensity <= 0.0) {
        outputTexture.write(inputPixel, gid);
        return;
    }
    
    half transientLen = mix(half(8.0), half(64.0), rand2) * bandwidthScale;
    half transientFreqFloor = transientLen * 3.0;
    half transientFreqCeil = transientLen * 5.0;
    float transientFreq = mix(transientFreqFloor, transientFreqCeil, rand3);
    half x = gid.x;
    half mod = 0.0;
    
    for (int i = 0; i < int(transientLen) && (x + i) < width; i++) {
        half t = half(i) / transientLen;
        half cosValue = cos(M_PI_H * t * transientFreq);
        half intensityMod = (1.0 - t) * (1.0 - t) * (rand3 * 3.0 - 1.0);
        mod += (cosValue * intensityMod);
    }
    
    half4 modPixel = inputPixel;
    modPixel.x += mod;
    half3 modYIQ = modPixel.xyz;
//    modYIQ = clampYIQ(modYIQ);
    half4 final = half4(modYIQ, 1.0);
    outputTexture.write(final, gid);
}
