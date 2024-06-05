//
//  YIQCompose.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "YIQChannel.metal"
#include <metal_stdlib>
using namespace metal;

kernel void yiqCompose
(
 texture2d<float, access::read> sampleTexture [[texture(0)]],
 texture2d<float, access::read_write> outputTexture [[texture(1)]],
 constant float4& channelMix [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float4 samplePixel = sampleTexture.read(gid);
    float4 outputPixel = outputTexture.read(gid);
    
    float y = mix(outputPixel.x, samplePixel.x, channelMix.x);
    float i = mix(outputPixel.y, samplePixel.y, channelMix.y);
    float q = mix(outputPixel.z, samplePixel.z, channelMix.z);
    float a = mix(outputPixel.w, samplePixel.w, channelMix.w);
    float4 result = float4(y, i, q, a);
    outputTexture.write(result, gid);
}
