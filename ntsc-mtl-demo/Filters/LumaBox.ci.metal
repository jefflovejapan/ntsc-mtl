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

extern "C" float4 LumaBox(coreimage::sampler s) {
    float2 imageOrigin = s.origin();
    float2 imageSize = s.size();
    float2 current = s.coord();
    
    float2 anotherCoord = float2(current.x + (1.0 / imageSize.x), current.y);
    float2 clampedCoord = clampCoord(anotherCoord, imageOrigin, imageSize);
    float4 sample = s.sample(clampedCoord);
    return sample;
    
//    float2 sampleCoord = clampCoord(anotherCoord, imageOrigin, imageSize);
    
//    float4 currentSample = s.sample(current);
//    
//    // Output the result
//    return float4(sample.r, currentSample.yzw);
}
