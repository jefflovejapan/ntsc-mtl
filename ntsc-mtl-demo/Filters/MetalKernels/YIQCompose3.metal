//
//  YIQCompose3.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void yiqCompose3
(
 texture2d<float, access::read> yTexture [[texture(0)]],
 texture2d<float, access::read> iTexture [[texture(1)]],
 texture2d<float, access::read> qTexture [[texture(2)]],
 texture2d<float, access::read_write> outputTexture [[texture(3)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float y = yTexture.read(gid).x;
    float i = iTexture.read(gid).y;
    float q = qTexture.read(gid).z;
    float4 result = float4(y, i, q, 1.0);
    outputTexture.write(result, gid);
}
