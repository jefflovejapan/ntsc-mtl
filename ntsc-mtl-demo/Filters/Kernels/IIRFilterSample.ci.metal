//
//  IIRFilterSample.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRFilterSample(coreimage::sample_t sample, coreimage::sample_t sideEffected, float numerator, float4 factors) {
    float4 yiqSample = ToYIQ(sample);
    float4 yiqSideEffected = ToYIQ(sideEffected);
    float4 yiq = yiqSideEffected + (numerator * yiqSample);
    float4 rgb = ToRGB(yiq);
    float4 mixed = factors * rgb;
    float4 unmixed = (1 - factors) * sample;
    return mixed + unmixed;
}

