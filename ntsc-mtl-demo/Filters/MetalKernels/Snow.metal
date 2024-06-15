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
    half4 randomPixel = randomTexture.read(gid);    // uniform random values
    
    float scaledFlatTerm = (1.0f - anisotropy) * intensity;
    
    float smoothTerm = smoothstep(min(intensity, 1.0f - intensity), max(intensity, 1.0f - intensity), float(randomPixel.x)) * anisotropy;
    smoothTerm = intensity > 0.5f ? smoothTerm : (1.0f - smoothTerm);
    smoothTerm = smoothTerm * anisotropy * intensity;
    float snow = scaledFlatTerm + smoothTerm;
    
    half4 outPx = inputPixel;
    outPx.x += (half(snow) * mix(-1.0h, 2.0h, randomPixel.y) * 0.125h);
    outputTexture.write(outPx, gid);
}
