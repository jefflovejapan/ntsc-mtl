//
//  YIQCompose.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void yiqCompose
(
 texture2d<half, access::read> sampleTexture [[texture(0)]],
 texture2d<half, access::read> fallbackTexture [[texture(1)]],
 texture2d<half, access::read_write> outputTexture [[texture(2)]],
 constant half4& channelMix [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 samplePixel = sampleTexture.read(gid);
    half4 fallbackPixel = fallbackTexture.read(gid);
    
    half y = mix(fallbackPixel.x, samplePixel.x, channelMix.x);
    half i = mix(fallbackPixel.y, samplePixel.y, channelMix.y);
    half q = mix(fallbackPixel.z, samplePixel.z, channelMix.z);
    half4 result = half4(y, i, q, 1.0);
    outputTexture.write(result, gid);
}
