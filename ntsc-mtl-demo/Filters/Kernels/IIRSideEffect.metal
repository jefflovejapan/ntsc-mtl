//
//  IIRSideEffect.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRSideEffect(coreimage::sample_t currentSample, coreimage::sample_t sideEffected, coreimage::sample_t filteredSample, float numerator, float denominator) {
    float4 yiqCurrentSample = ToYIQ(currentSample);
    float4 yiqSideEffected = ToYIQ(sideEffected);
    float4 yiqFilteredSample = ToYIQ(filteredSample);
    float4 yiqCombined = yiqSideEffected + (numerator * yiqCurrentSample) - (denominator * yiqFilteredSample);
    return ToRGB(yiqCombined);
}
