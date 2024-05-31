//
//  IIRInitialCondition.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRInitialCondition (coreimage::sample_t inputImage, coreimage::sample_t sideEffected, float aSum, float cSum, float4 factors)
{
    float4 yiqInput = ToYIQ(inputImage);
    float4 yiqSideEffected = ToYIQ(sideEffected);
    float4 yiqOutput = (aSum * yiqSideEffected - cSum) * yiqInput;
    float4 yiqMixed = factors * yiqOutput;
    float4 yiqUnmixed = (1 - factors) * yiqInput;
    float4 finalYIQ = yiqMixed + yiqUnmixed;
    return ToRGB(finalYIQ);
}
