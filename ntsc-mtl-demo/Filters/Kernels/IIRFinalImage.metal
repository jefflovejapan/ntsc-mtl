//
//  IIRSideEffect.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRFinalImage(coreimage::sample_t currentSample, coreimage::sample_t filteredSample, float scale) {
    return ((filteredSample - currentSample) * scale) + currentSample;
}
