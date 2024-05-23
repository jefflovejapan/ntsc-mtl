//
//  HDRZebra.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 HDRZebra (coreimage::sample_t s, float time, coreimage::destination dest)
{
    float diagLine = dest.coord().x + dest.coord().y;
    float zebra = fract(diagLine/20.0 + time*2.0);
    if ((zebra > 0.5) && (s.r > 1 || s.g > 1 || s.b > 1))
        return float4(2.0, 0.0, 0.0, 1.0);
    return s;
}
