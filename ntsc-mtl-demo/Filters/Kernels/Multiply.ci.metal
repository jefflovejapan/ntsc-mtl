//
//  Multiply.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 Multiply(coreimage::sample_t mainImage, coreimage::sample_t otherImage)
{
    float4 yiqMainImage = ToYIQ((mainImage));
    float4 yiqOtherImage = ToYIQ(otherImage);
    float4 multiplied = yiqMainImage * yiqOtherImage;
    return ToRGB(multiplied);
    
}
