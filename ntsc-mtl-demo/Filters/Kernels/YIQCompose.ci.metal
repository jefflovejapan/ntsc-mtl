//
//  YIQCompose.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 YIQCompose(coreimage::sample_t ySample, coreimage::sample_t iSample, coreimage::sample_t qSample) {
    return float4(ySample.r, iSample.g, qSample.b, 1);
}
