//
//  ChannelMixer.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

#include "YIQ.metal"
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 ChannelMixer(coreimage::sample_t mixImage, coreimage::sample_t inverseMixImage, float4 factors)
{
    float4 mixedImage = factors * ToYIQ(mixImage);
    float4 unmixedImage = (1 - factors) * ToYIQ(inverseMixImage);
    float4 yiqImage = mixedImage + unmixedImage;
    return ToRGB(yiqImage);
}

