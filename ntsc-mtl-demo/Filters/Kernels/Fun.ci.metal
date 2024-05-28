//
//  Fun.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 Fun (coreimage::sampler s, coreimage::destination dest)
{
    float2 imageSize = s.size();
    float2 current = s.coord();
    
    float2 newCoord = current + float2((500.0 / imageSize.x), 0.0);
    float4 sample = s.sample(newCoord);
    return sample;
}
