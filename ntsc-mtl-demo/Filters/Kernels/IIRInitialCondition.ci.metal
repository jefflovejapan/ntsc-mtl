//
//  IIRInitialCondition.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 IIRInitialCondition (coreimage::sample_t inputImage, coreimage::sample_t sideEffected, float aSum, float cSum)
{
    return (aSum * sideEffected - cSum) * inputImage;
}
