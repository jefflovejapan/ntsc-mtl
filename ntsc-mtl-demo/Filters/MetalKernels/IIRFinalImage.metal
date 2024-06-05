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
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read_write> filteredImageTexture [[texture(1)]],
 constant half &scale [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 currentSample = inputTexture.read(gid);
    half4 filteredSample = filteredImageTexture.read(gid);
    half4 combined = ((filteredSample - currentSample) * scale) + currentSample;
    combined.w = 1;
    filteredImageTexture.write(combined, gid);
}

