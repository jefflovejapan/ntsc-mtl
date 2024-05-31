//
//  MultiplyLuma.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 MultiplyLuma(coreimage::sample_t mainImage, coreimage::sample_t otherImage, float intensity)
{
    float4 yiqMainImage = ToYIQ((mainImage));
    float4 yiqOtherImage = ToYIQ(otherImage);
    yiqMainImage.x += (yiqOtherImage.x * 0.25 * intensity);
    return ToRGB(yiqMainImage);
}

