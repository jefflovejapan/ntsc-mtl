//
//  IIRSideEffect.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRSideEffect(coreimage::sample_t currentSample, coreimage::sample_t sideEffected, coreimage::sample_t filteredSample, float numerator, float denominator) {
    // return z[i+1] +
    return sideEffected + (numerator * currentSample) - (denominator * filteredSample);
}


/*
 To operate on the y channel only:
 
 let filtered = filter(img)
 let composed = yiqCompose(filtered, unfiltered)
 */
