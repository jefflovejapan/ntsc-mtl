//
//  IIRFilterSample.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRFilterSample(coreimage::sample_t sample, coreimage::sample_t sideEffected, float numerator) {
    float4 yiqSample = ToYIQ(sample);
    float4 yiqSideEffected = ToYIQ(sideEffected);
    float4 yiq = yiqSideEffected + (numerator * yiqSample);
    return ToRGB(yiq);
}

