//
//  EdgeWave.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-16.
//

#include "ShiftRowInline.metal"
#include <metal_stdlib>
using namespace metal;


kernel void edgeWave
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant float &intensity [[buffer(0)]],
 constant float &bandwidthScale [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 randomPixel = randomTexture.read(gid);
//    /*
//     - I've got a pixel at y = 70 that I want to map to 0
//     - Height of the tex is 100
//     - height of the tex - y = 30
//     - height of the tex - y - numAffected
//     */
    
    float shift = (float(randomPixel.x) / 0.022) * intensity * 0.5 * bandwidthScale;
    
    shiftRowInline(inputTexture, outputTexture, shift, shift > 0.0f ? 0 : inputTexture.get_width() - 1, gid);
}
