//
//  RGB.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

constant half3x3 yiqToRGBMatrix = half3x3
(
 half3(1.0, 1.0, 1.0),
 half3(0.956, -0.272, -1.106),
 half3(0.619, -0.647, 1.703)
 );

kernel void convertToRGB
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 
 uint2 gid [[thread_position_in_grid]]) {
    half4 yiqa = inputTexture.read(gid);
    half3 yiq = yiqa.xyz;
    half3 rgb = yiqToRGBMatrix * yiq;
    rgb = clampRGB(rgb);
    outputTexture.write(half4(rgb, 1.0), gid);
}
