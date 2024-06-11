//
//  Snow2.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-09.
//

#include <metal_stdlib>
using namespace metal;

kernel void snow2
(
 texture2d<half, access::read> inTexture [[texture(0)]],
 texture2d<half, access::read> geoTexture [[texture(1)]],
 texture2d<half, access::write> outTexture [[texture(2)]],
 constant float &bandwidthScale [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    // Read the current value from the output texture
    half4 currentValue = inTexture.read(gid);

    // Get the geometric distribution value for this thread
    half4 geomValue = geoTexture.read(gid);

    // Calculate the speckle effect
    half4 transientLen = geomValue * bandwidthScale;
    half4 transientFreq = geomValue * bandwidthScale * 4.0;

    // Apply speckle effect using cosine function
    half x = half(gid.x);
    half4 speckleValue = (cos((x * M_PI_H) / transientFreq) * (half(1.0) - x / transientLen) * (half(1.0) - x / transientLen));
    half3 current = currentValue.xyz;
    half3 speckle = speckleValue.xyz;
    half4 total = half4(current + speckle, 1.0);

    // Update the texture with the new value
    outTexture.write(total, gid);
}
