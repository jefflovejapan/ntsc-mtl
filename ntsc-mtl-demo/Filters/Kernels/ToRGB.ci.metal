//
//  ToRGB.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
#include "RGBtoYIQ.metal"
using namespace metal;

extern "C" float4 ToRGB (coreimage::sample_t s)
{
    float3 yiq = s.rgb;
    float3 rgb = YIQ_TO_RGB_MATRIX * yiq;
    return float4(rgb, s.a);
}

