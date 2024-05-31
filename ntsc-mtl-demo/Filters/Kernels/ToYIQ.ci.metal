//
//  ToYIQ.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
#include "RGBtoYIQ.metal"
using namespace metal;

extern "C" float4 ToYIQ (coreimage::sample_t s)
{
    float3 yiq = RGB_TO_YIQ_MATRIX * s.rgb;
    return float4(yiq, s.a);
}
