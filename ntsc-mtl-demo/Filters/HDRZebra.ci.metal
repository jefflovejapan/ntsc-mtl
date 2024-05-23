//
//  HDRZebra.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 Blue (coreimage::sample_t s, float time, coreimage::destination dest)
{
    return float4(0.0, 0.0, 1.0, 1.0);
}
