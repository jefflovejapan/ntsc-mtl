//
//  RGBtoYIQ.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-30.
//

#include <metal_stdlib>
using namespace metal;

#define YIQ_TO_RGB_MATRIX float3x3(\
float3(1.0, 0.9563, 0.6210),\
float3(1.0, -0.2721, -0.6474),\
float3(1.0, -1.1070, 1.7046))

#define RGB_TO_YIQ_MATRIX float3x3(\
float3(0.299, 0.587, 0.114),\
float3(0.595716, -0.274453, -0.321263),\
float3(0.211456, -0.522591, 0.311135))

#define ToYIQ(rgba) float4(RGB_TO_YIQ_MATRIX * (rgba.xyz), rgba.w)
#define ToRGB(yiqa) float4(YIQ_TO_RGB_MATRIX * (yiqa.xyz), yiqa.w)
