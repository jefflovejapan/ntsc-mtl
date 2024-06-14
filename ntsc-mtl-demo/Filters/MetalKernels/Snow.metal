//
//  Snow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

constant half PI_16 = half(3.140625);

half sampleGeometric
(
 half u,    // uniform random variable
 half p     // line snow intensity
 ) {
    return log(u) / log(p);
}

kernel void snow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant float &intensity [[buffer(0)]],
 constant float &anisotropy [[buffer(1)]],
 constant half &bandwidthScale [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    
    half4 inputPixel = inputTexture.read(gid);
    half4 randomPixel = randomTexture.read(gid);
    float randX = float(randomPixel.x);
    float randY = float(randomPixel.y);
    float randZ = float(randomPixel.z);
    float logisticFactor = exp((randX - intensity) / (intensity * (1.0 - intensity) * (1.0 - anisotropy)));
    float lineSnowIntensity = anisotropy / (1.0 + logisticFactor) + intensity * (1.0 - anisotropy);
    lineSnowIntensity *= 0.125;
    lineSnowIntensity = clamp(lineSnowIntensity, float(0.0), float(1.0));
    if (lineSnowIntensity <= 0.0) {
        outputTexture.write(inputPixel, gid);
        return;
    }
    
    float transientLen = mix(8.0, 64.0, randY) * float(bandwidthScale);
    float transientFreq = mix((transientLen * 3.0), (transientLen * 5.0), randZ);
    float x = fmod(float(gid.x), transientLen);
    float transientEffect = cos((x * M_PI_F) / transientFreq) * pow((1.0 - x / transientLen), 2.0);
    half luma = inputPixel.x;
    luma += half(transientEffect);
    half4 outPixel = inputPixel;
    outPixel.x = luma;
    outputTexture.write(outPixel, gid);
}
