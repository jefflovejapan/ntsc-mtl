//
//  ShiftRow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

#include <metal_stdlib>
using namespace metal;

kernel void shiftRow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant uint &offsetRows [[buffer(0)]],
 constant uint &boundaryColumnIndex [[buffer(1)]],
 constant float &shift [[buffer(2)]],
 constant float &bandwidthScale [[buffer(3)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 thisPixel = inputTexture.read(gid);
    uint height = inputTexture.get_height();
    uint minRowForEffect = height - offsetRows;
    if (gid.y < minRowForEffect) {
        outputTexture.write(thisPixel, gid);
        return;
    }
    float rowShift = pow(shift * (float(gid.y) / float(height)), 1.5);
    half rand = randomTexture.read(uint2(0, gid.y)).x;
    rand = mix(HALF_MIN, HALF_MAX, rand);
    float noisyShift = (rowShift + (rand - 0.5)) * bandwidthScale;
    half shiftFrac = 0.0;
    if (noisyShift < 0.0) {
        shiftFrac = 1.0 - abs(fract(half(noisyShift)));
    } else {
        shiftFrac = fract(half(noisyShift));
    }
    
    uint textureWidth = inputTexture.get_width();
    int shiftInt = shift < 0.0 ? 1 : 0;
    int desiredPixelIndex = gid.x + shiftInt;
    uint pixelIndex = 0;
    if (desiredPixelIndex < 0) {
        pixelIndex = boundaryColumnIndex;
    } else if (uint(desiredPixelIndex) > (textureWidth - 1)) {
        pixelIndex = boundaryColumnIndex;
    } else {
        pixelIndex = uint(desiredPixelIndex);
    }
    half4 otherPixel = inputTexture.read(uint2(pixelIndex, gid.y));
    half4 mixel = (shiftFrac * thisPixel) + ((1.0 - shiftFrac) * otherPixel);
    outputTexture.write(mixel, gid);
}
