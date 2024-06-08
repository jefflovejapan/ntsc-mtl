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
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant int &offsetPixelCount [[buffer(0)]],
 constant uint &boundaryColumnIndex [[buffer(1)]],
 constant uint &minRowForEffect [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 thisPixel = inputTexture.read(gid);
    if (gid.y < minRowForEffect) {
        outputTexture.write(thisPixel, gid);
        return;
    }
    uint textureWidth = inputTexture.get_width();
    int desiredPixelIndex = gid.x + offsetPixelCount;
    uint pixelIndex = 0;
    if (desiredPixelIndex < 0) {
        pixelIndex = boundaryColumnIndex;
    } else if (uint(desiredPixelIndex) > (textureWidth - 1)) {
        pixelIndex = boundaryColumnIndex;
    } else {
        pixelIndex = uint(desiredPixelIndex);
    }
    half4 otherPixel = inputTexture.read(uint2(pixelIndex, gid.y));
    half4 mixel = (0.5 * thisPixel) + (0.5 * otherPixel);
    
    /*
     Get some values as a function of our position, shift, and boundary handling (shift_int, shift_frac, boundary_value, and prev)
     
     There's some branching depending on whether shift_int is greater than 0. We're either shifting forwards or backwards
     
     We're using this mutable "prev" thing to keep track of our last pixel value
     
     I think we're just doing this because we're shifting an array in place. If we do this in shadertown we can just sample from a different place in the texture
     
     shift_int is either 1 or 0 depending on whether shift is < 0 or not
     
     boundaryValue is a constant:
        - first pixel if shift_int is >= 0
        - last pixel if shift_int is < 0
     
     shift_frac is what proportion of the neighboring frame to use
     
     prev is always a constant related to shift_int
     return (shift_int, shift_frac, boundary_value, and prev)
     */
    outputTexture.write(mixel, gid);
}
