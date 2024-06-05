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
 texture2d<float, access::read> fallbackTexture [[texture(1)]],
 texture2d<float, access::read_write> outputTexture [[texture(2)]],
 constant float4& channelMix [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float4 samplePixel = sampleTexture.read(gid);
    float4 fallbackPixel = fallbackTexture.read(gid);
    
    float y = mix(fallbackPixel.x, samplePixel.x, channelMix.x);
    float i = mix(fallbackPixel.y, samplePixel.y, channelMix.y);
    float q = mix(fallbackPixel.z, samplePixel.z, channelMix.z);
    float4 result = float4(y, i, q, 1.0);
    outputTexture.write(result, gid);
}
