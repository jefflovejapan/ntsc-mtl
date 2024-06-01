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

extern "C" float4 Snow(coreimage::sample_t inputImage, float intensity, float anisotropy, float bandwidthScale, int width, float random, coreimage::destination dest)
{
    float4 yiqInput = ToYIQ(inputImage);
    float2 coord = dest.coord();
    
    // Parameters conversion
    float intensityVal = intensity;
    float anisotropyVal = anisotropy;
    
    // Compute logistic factor
    float logisticFactor = exp((random - intensityVal) /
                               (intensityVal * (1.0 - intensityVal) * (1.0 - anisotropyVal)));
    float lineSnowIntensity = anisotropyVal / (1.0 + logisticFactor) + intensityVal * (1.0 - anisotropyVal);
    
    // Adjust intensity
    lineSnowIntensity *= 0.125;
    lineSnowIntensity = clamp(lineSnowIntensity, 0.0, 1.0);
    
    if (lineSnowIntensity <= 0.0) {
        return inputImage;
    }
    
    // Apply "snow" effect
    float transientLen = rand(coord, 1.0) * (64.0 - 8.0) + 8.0 * bandwidthScale;
    float transientFreq = rand(coord, 2.0) * (transientLen * 5.0 - transientLen * 3.0) + transientLen * 3.0;
    float x = coord.x;
    
    float t = float(x) / transientLen;
    float cosValue = cos(M_PI_F * t * transientFreq);
    float intensityMod = (1.0 - t) * (1.0 - t) * (rand(coord + float2(x, 0), 3.0) * 3.0 - 1.0);
    
    float4 modPixel = yiqInput + float4(cosValue * intensityMod, cosValue * intensityMod, cosValue * intensityMod, 0.0);
    modPixel = clamp(modPixel, 0.0, 1.0);
    return ToRGB(modPixel);
}



