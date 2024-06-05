//
//  IIRFinalImage.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirFinalImage
(
 texture2d<float, access::read> inputTexture [[texture(0)]],
 texture2d<float, access::read_write> scratchTexture [[texture(1)]],
 constant float &scale [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float4 currentSample = inputTexture.read(gid);
    float4 filteredSample = scratchTexture.read(gid);
    float4 combined = ((filteredSample - currentSample) * scale) + currentSample;
    combined.w = 1;
    scratchTexture.write(combined, gid);
}

