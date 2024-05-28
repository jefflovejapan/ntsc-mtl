//
//  FirstColumn.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 FirstColumn(coreimage::sampler s, coreimage::destination dest)
{
    return s.sample(float2(0, dest.coord().y));
}

