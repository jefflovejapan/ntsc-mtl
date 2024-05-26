//
//  LumaNotch.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

// Helper function to clamp coordinates within the image bounds given an origin
static float2 clampCoord(float2 coord, float2 origin, float2 size) {
    return float2(
        clamp(coord.x, origin.x, origin.x + size.x - 1.0),
        clamp(coord.y, origin.y, origin.y + size.y - 1.0)
    );
}

// TODO: Pretty sure that I need to account for orientation here

extern "C" float4 LumaNotch(coreimage::sampler s) {
    float2 imageOrigin = s.origin();
    float2 imageSize = s.size();
    float2 current = s.coord();
    
    // Define symmetric sampling offsets for 5-tap horizontal box filter
    float2 offsets[5] = {
        float2((-2.0 / imageSize.x), 0.0),
        float2((-1.0 / imageSize.x), 0.0),
        float2(0.0, 0.0),
        float2((1.0 / imageSize.x), 0.0),
        float2((2.0 / imageSize.x), 0.0)
    };
    
    float averageR = 0.0;
    
    // Accumulate the samples
    for (int i = 0; i < 5; ++i) {
        float2 sampleCoord = clampCoord(current + offsets[i], imageOrigin, imageSize);
        float4 sample = s.sample(sampleCoord);
        averageR += sample.r;
    }
    
    // Calculate the average
    averageR /= 5.0;
    
    // Output the result
    float4 sampleCurrent = s.sample(current);
    return float4(averageR, sampleCurrent.g, sampleCurrent.b, sampleCurrent.a);


}
