//
//  ToYIQ.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

constant float3x3 RGB_TO_YIQ_MATRIX = float3x3(float3(0.299, 0.587, 0.114),
                                               float3(0.595716, -0.274453, -0.321263),
                                               float3(0.211456, -0.522591, 0.311135));

extern "C" float4 ToYIQ (coreimage::sample_t s)
{
    float3 yiq = RGB_TO_YIQ_MATRIX * s.rgb;
    return float4(yiq, s.a);
}
