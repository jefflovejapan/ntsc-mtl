//
//  Snow.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 Snow(coreimage::sample_t inputImage, coreimage::sample_t randomImage, float intensity, float anisotropy, float bandwidthScale, int width, coreimage::destination dest)
{
    float4 yiqInput = ToYIQ(inputImage);
    float rand1 = mix(FLT_MIN, FLT_MAX, randomImage.r);
    float rand2 = mix(FLT_MIN, FLT_MAX, randomImage.g);
    float rand3 = mix(FLT_MIN, FLT_MAX, randomImage.b);
    float2 coord = dest.coord();
    
    /*
     let logistic_factor = ((rng.gen::<f64>() - intensity)
             / (intensity * (1.0 - intensity) * (1.0 - anisotropy)))
             .exp();
     */
    float logisticFactor = exp((rand1 - intensity) / (intensity * (1.0 - intensity) * (1.0 - anisotropy)));
    
    /*
     let mut line_snow_intensity: f64 =
          anisotropy / (1.0 + logistic_factor) + intensity * (1.0 - anisotropy);
     */
    float lineSnowIntensity = (anisotropy / (1.0 + logisticFactor)) + (intensity * (1.0 - anisotropy));

    // Adjust intensity
    lineSnowIntensity *= 0.125;
    lineSnowIntensity = clamp(lineSnowIntensity, 0.0, 1.0);
    
    if (lineSnowIntensity <= 0.0) {
        return inputImage;
    }
    
    // Apply "snow" effec
    float transientLen = mix(8.0, 64.0, rand2) * bandwidthScale;
    float transientFreqFloor = transientLen * 3.0;
    float transientFreqCeil = transientLen * 5.0;
    float transientFreq = mix(transientFreqFloor, transientFreqCeil, rand3);
    float x = coord.x;
    float mod = 0.0;
    
    for (int i = 0; i < int(transientLen) && (x + i) < width; i++) {
        float t = float(i) / transientLen;
        float cosValue = cos(M_PI_F * t * transientFreq);
        float intensityMod = (1.0 - t) * (1.0 - t) * (rand3 * 3.0 - 1.0);
        mod += cosValue * intensityMod;
    }
    
    float4 modPixel = yiqInput;
    modPixel.x += mod;
    modPixel.x = clamp(modPixel.x, 0.0, 1.0);
    return ToRGB(modPixel);
}
