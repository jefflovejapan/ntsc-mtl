//
//  YIQCompose.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void yiqCompose
(
 texture2d<half, access::read> sampleTexture [[texture(0)]],
 texture2d<half, access::read> fallbackTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half4& channelMix [[buffer(0)]],
 constant uint& delay [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(sampleTexture.get_width(), min(fallbackTexture.get_width(), outputTexture.get_width()));
//    half minHeight = min(sampleTexture.get_height(), min(fallbackTexture.get_height(), outputTexture.get_height()));
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 fallbackPixel = fallbackTexture.read(gid);
    uint2 sampleGID = gid;
    sampleGID.y += delay;
    if (sampleGID.y >= sampleTexture.get_height()) {
        outputTexture.write(fallbackPixel, gid);
    }
    half4 samplePixel = sampleTexture.read(sampleGID);
    
    half y = mix(fallbackPixel.x, samplePixel.x, channelMix.x);
    half i = mix(fallbackPixel.y, samplePixel.y, channelMix.y);
    half q = mix(fallbackPixel.z, samplePixel.z, channelMix.z);
    half3 yiq = half3(y, i, q);
//    yiq = clampYIQ(yiq);
    half4 result = half4(yiq, 1.0);
    outputTexture.write(result, gid);
}
