//
//  Snow.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

// Random number generator using a simple linear congruential generator (LCG)
float rand(float2 coord, float seed) {
    return fract(sin(dot(coord + seed, float2(12.9898, 78.233))) * 43758.5453);
}

extern "C" float4 Snow(coreimage::sample_t inputImage, coreimage::sample_t randomImage, float intensity, float anisotropy, float bandwidthScale, int width, coreimage::destination dest)
{
    float4 yiqInput = ToYIQ(inputImage);
    float rand1 = randomImage.r;
    float rand2 = randomImage.g;
    float rand3 = randomImage.b;
    float2 coord = dest.coord();
    
    // Compute logistic factor
    float logisticFactor = exp((rand1 - intensity) / (intensity * (1.0 - intensity) * (1.0 - anisotropy)));
    float lineSnowIntensity = anisotropy / (1.0 + logisticFactor) + intensity * (1.0 - anisotropy);

    // Adjust intensity
    lineSnowIntensity *= 0.125;
    lineSnowIntensity = clamp(lineSnowIntensity, 0.0, 1.0);
    
    if (lineSnowIntensity <= 0.0) {
        return inputImage;
    }
    
    // Apply "snow" effec
    float transientLen = rand2 * (64.0 - 8.0) + 8.0 * bandwidthScale;
    float transientFreq = rand3 * (transientLen * 5.0 - transientLen * 3.0) + transientLen * 3.0;
    float x = coord.x;
    float mod = 0.0;
    
    for (int i = 0; i < int(transientLen) && x + i < width; i++) {
        float t = float(i) / transientLen;
        float cosValue = cos(M_PI_F * t * transientFreq);
        float intensityMod = (1.0 - t) * (1.0 - t) * (rand3 * 3.0 - 1.0);
        mod += cosValue * intensityMod;
    }
    
    float4 modPixel = yiqInput + float4(mod, mod, mod, 0.0);
    return clamp(modPixel, 0.0, 1.0);
    return ToRGB(modPixel);
}
