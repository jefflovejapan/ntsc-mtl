//
//  Multiply.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 Multiply(coreimage::sample_t imageA, coreimage::sample_t imageB)
{
    return imageA * imageB;
}
