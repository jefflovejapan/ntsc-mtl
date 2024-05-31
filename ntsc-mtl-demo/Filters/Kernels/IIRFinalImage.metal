//
//  IIRSideEffect.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRFinalImage(coreimage::sample_t currentSample, coreimage::sample_t filteredSample, float scale, float4 factors) {
    float4 yiqCurrentSample = ToYIQ(currentSample);
    float4 yiqFilteredSample = ToYIQ(filteredSample);
    float4 yiqCombined = ((yiqFilteredSample - yiqCurrentSample) * scale) + yiqCurrentSample;
    float4 yiqMixed = factors * yiqCombined;
    float4 yiqUnmixed = (1-factors) * currentSample;
    float4 yiqFinal = yiqMixed + yiqUnmixed;
    return ToRGB(yiqFinal);
}
