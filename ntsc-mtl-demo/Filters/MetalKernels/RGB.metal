//
//  RGB.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

constant float3x3 yiqToRGBMatrix = float3x3
(
 float3(1.0, 1.0, 1.0),
 float3(0.956, -0.272, -1.106),
 float3(0.619, -0.647, 1.703)
 );

kernel void convertToRGB(texture2d<float, access::read_write> texture [[texture(0)]], uint2 gid [[thread_position_in_grid]]) {
    float4 yiqa = texture.read(gid);
    float3 yiq = yiqa.xyz;
    float3 rgb = yiqToRGBMatrix * yiq;
    texture.write(float4(rgb, yiqa.w), gid);
}
