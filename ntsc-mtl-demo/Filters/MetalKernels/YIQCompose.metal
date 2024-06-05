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
 texture2d<float, access::read_write> sampleTexture [[texture(0)]],
 texture2d<float, access::read_write> outputTexture [[texture(1)]],
 constant YIQChannel& channel [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float4 samplePixel = sampleTexture.read(gid);
    float4 outputPixel = outputTexture.read(gid);
    switch (channel) {
        case YIQChannelY:
            outputPixel.x = samplePixel.x;
        case YIQChannelI:
            outputPixel.y = samplePixel.y;
        case YIQChannelQ:
            outputPixel.z = samplePixel.z;
    }
    outputTexture.write(outputPixel, gid);
}
