//
//  ShiftRow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

#include "ShiftRowInline.metal"
#include <metal_stdlib>
using namespace metal;

kernel void shiftRow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant uint &effectHeight [[buffer(0)]],
 constant uint &offsetRows [[buffer(1)]],
 constant float &shift [[buffer(2)]],
 constant uint &boundaryColumnIndex [[buffer(3)]],
 constant float &bandwidthScale [[buffer(4)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 thisPixel = inputTexture.read(gid);
    uint texHeight = inputTexture.get_height();
    uint numAffectedRows = effectHeight - offsetRows;
    uint effectStartRow = texHeight - numAffectedRows;
    if (gid.y < effectStartRow) {
        outputTexture.write(thisPixel, gid);
        return;
    }
//    /*
//     - I've got a pixel at y = 70 that I want to map to 0
//     - Height of the tex is 100
//     - height of the tex - y = 30
//     - height of the tex - y - numAffected
//     */
    uint rowWithinAffected = (texHeight - 1 - gid.y);
    
    float rowShift = shift * pow((float(rowWithinAffected) / float(numAffectedRows)), 1.5);
    half rand = randomTexture.read(uint2(0, gid.y)).x;
    float noisyShift = (rowShift + (rand - 0.5)) * bandwidthScale;
    shiftRowInline(inputTexture, outputTexture, noisyShift, boundaryColumnIndex, gid);
}
