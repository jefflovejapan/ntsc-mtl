//
//  LumaBox.ci.metal
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
                  clamp(coord.y, origin.y, origin.y + size.y - 1.0));
}

extern "C" float4 LumaBox (coreimage::sampler s)
{
    float4 imageExtent = s.extent();
    float2 imageOrigin = imageExtent.xy;
    float2 imageSize = imageExtent.zw;
    float2 current = s.coord();
    
    float2 left2 = clampCoord(current + float2(-2, 0), imageOrigin, imageSize);
    float2 left1 = clampCoord(current + float2(-1, 0), imageOrigin, imageSize);
    float2 right1 = clampCoord(current + float2(1, 0), imageOrigin, imageSize);
    
    // Sample the pixel values
    float4 sampleLeft2 = s.sample(left2);
    float4 sampleLeft1 = s.sample(left1);
    float4 sampleCurrent = s.sample(current);
    float4 sampleRight1 = s.sample(right1);
    
    float averageR = (sampleLeft2.r + sampleLeft1.r + sampleCurrent.r + sampleRight1.r) / 4.0;
    
    return float4(averageR, sampleCurrent.g, sampleCurrent.b, sampleCurrent.a);
}
