//
//  RoundTrip.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-30.
//

#include "RGBtoYIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 RoundTrip (coreimage::sample_t s)
{
    float3 yiq = RGB_TO_YIQ_MATRIX * s.rgb;
    float3 newRGB = YIQ_TO_RGB_MATRIX * yiq;
    return float4(newRGB, s.a);
}

