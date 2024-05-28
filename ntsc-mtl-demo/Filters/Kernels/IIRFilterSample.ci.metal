//
//  IIRFilterSample.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRFilterSample(coreimage::sample_t sample, coreimage::sample_t prevSample, float numerator) {
    return prevSample + (numerator * sample);
}

