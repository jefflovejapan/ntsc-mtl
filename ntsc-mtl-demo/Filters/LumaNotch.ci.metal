//
//  LumaNotch.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 LumaNotch (coreimage::sample_t s, float time, float intensity, coreimage::destination dest)
{
    // Define the blue color
    float4 blueColor = float4(0.0, 0.0, 1.0, 1.0);

    // Blend the blue color with the input pixel color
    float4 blendedColor = mix(s, blueColor, intensity);

    return blendedColor;
}
