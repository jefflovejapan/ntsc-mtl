//
//  MultiplyLuma.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 MultiplyLuma(coreimage::sample_t mainImage, coreimage::sample_t otherImage, float intensity)
{
    mainImage.r += (otherImage.r * 0.25 * intensity);
    return mainImage;
}

