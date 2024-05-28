//
//  ChannelMixer.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 ChannelMixer(coreimage::sample_t s, float4 factors)
{
    return s * factors;
}

