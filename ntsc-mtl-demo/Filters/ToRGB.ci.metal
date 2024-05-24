//
//  ToRGB.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

constant float3x3 YIQ_TO_RGB_MATRIX = float3x3(float3(1.0, 0.9563, 0.6210),
                                               float3(1.0, -0.2721, -0.6474),
                                               float3(1.0, -1.1070, 1.7046));

extern "C" float4 ToRGB (coreimage::sample_t s)
{
    float3 yiq = s.rgb;
    float3 rgb = YIQ_TO_RGB_MATRIX * yiq;
    return float4(rgb, s.a);
}

