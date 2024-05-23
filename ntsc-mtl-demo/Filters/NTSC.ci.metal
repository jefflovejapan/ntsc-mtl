//
//  HDRZebra.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 NTSC (coreimage::sample_t s, float time, coreimage::destination dest)
{
    // Define the blue color
    float4 blueColor = float4(0.0, 0.0, 1.0, 1.0);

    // Define the blending factor (0.5 for a 50/50 blend)
    float blendFactor = 0.5;

    // Blend the blue color with the input pixel color
    float4 blendedColor = mix(s, blueColor, blendFactor);

    return blendedColor;
}
