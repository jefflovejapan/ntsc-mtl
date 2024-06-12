//
//  SnowIntensity.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

#include <metal_stdlib>
using namespace metal;

kernel void snowIntensity
(
 texture2d<half, access::read> uniformRandomTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant half &intensity [[buffer(0)]],
 constant half &anisotropy [[buffer(1)]],
 constant half &bandwidthScale [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half rnd = uniformRandomTexture.read(gid).x;
    float logisticFactor = exp(float(rnd - intensity) / float(intensity * (1.0 - intensity) * float(1.0 - anisotropy)));
    
    float lineSnowIntensity = (float(anisotropy) / (1.0 + logisticFactor)) + float(intensity * (1.0 - anisotropy));
    lineSnowIntensity *= 0.125;
    half halfIntensity = half(lineSnowIntensity);
    half4 out = half4(halfIntensity, halfIntensity, halfIntensity, half(1.0));
    outputTexture.write(out, gid);
}

