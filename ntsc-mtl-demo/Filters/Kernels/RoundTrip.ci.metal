//
//  RoundTrip.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-30.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 RoundTrip (coreimage::sample_t s)
{
    float3 yiq = ToYIQ(s.rgb);
    float3 newRGB = ToRGB(yiq);
    return float4(newRGB, s.a);
}

