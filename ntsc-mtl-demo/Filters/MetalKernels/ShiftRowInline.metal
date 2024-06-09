//
//  ShiftRowInline.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-09.
//

#include <metal_stdlib>
using namespace metal;

inline void shiftRowInline
(
 texture2d<half, access::read> inputTexture,
 texture2d<half, access::write> outputTexture,
 float shift,
 uint boundaryColumnIndex,
 uint2 gid
 ) {
    half shiftFrac = 0.0;
    if (shift < 0.0) {
        shiftFrac = 1.0 - abs(fract(half(shift)));
    } else {
        shiftFrac = fract(half(shift));
    }
    
    uint textureWidth = inputTexture.get_width();
    int shiftInt = int(shift);
    int desiredPixelIndex = gid.x + shiftInt;
    uint pixelIndex = 0;
    if (desiredPixelIndex < 0) {
        pixelIndex = boundaryColumnIndex;
    } else if (uint(desiredPixelIndex) > (textureWidth - 1)) {
        pixelIndex = boundaryColumnIndex;
    } else {
        pixelIndex = uint(desiredPixelIndex);
    }
    half4 thisPixel = inputTexture.read(gid);
    half4 otherPixel = inputTexture.read(uint2(pixelIndex, gid.y));
    half4 mixel = (shiftFrac * thisPixel) + ((1.0 - shiftFrac) * otherPixel);
    outputTexture.write(mixel, gid);
}
