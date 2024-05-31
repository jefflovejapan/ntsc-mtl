//
//  YIQCompose.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 YIQCompose(coreimage::sample_t ySample, coreimage::sample_t iSample, coreimage::sample_t qSample) {
    float4 yiqYSample = ToYIQ(ySample);
    float4 yiqISample = ToYIQ(iSample);
    float4 yiqQSample = ToYIQ(qSample);
    float4 composed = float4(yiqYSample.x, yiqISample.y, yiqQSample.z, 1);
    return ToRGB(composed);
}
