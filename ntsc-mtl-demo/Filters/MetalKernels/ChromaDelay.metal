//
//  ChromaDelay.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

#include <metal_stdlib>
using namespace metal;

constant half PI_16 = half(3.140625);

kernel void chromaDelay
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant half &horizShift [[buffer(0)]],
 constant int &vertShift [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inputPixel = inputTexture.read(gid);
    
    // vertShiftedY is gid.y + vertShift, clamped within bounds
    int vertShiftedY = int(gid.y);
    vertShiftedY += vertShift;
    vertShiftedY = clamp(vertShiftedY, 0, int(inputTexture.get_height()));
    
    // clampedX is gid.x + horizShift, clamped within bounds
    float clampedX = clamp(0.0, float(gid.x) + horizShift, float(inputTexture.get_width()));
    float clampedShift = clampedX - float(gid.x);
    float proportion = fract(clampedShift);
    // wholeShift is the whole part of the shift
    int wholeShift = int(clampedShift - proportion);
    
    // nextClampedX is gid.x + horizShift + sign(horizShift), clamped within bounds
    float nextClampedX = clamp(0.0, float(gid.x) + float(wholeShift) + float(sign(horizShift)), float(inputTexture.get_width()));
    
    half4 thisIQPixel = inputTexture.read(uint2(uint(clampedX), vertShiftedY));
    half4 nextIQPixel = inputTexture.read(uint2(uint(nextClampedX), vertShiftedY));
    half4 iqPixel = (half(1.0 - proportion) * thisIQPixel) + (half(proportion) * nextIQPixel);
    half4 outPixel = half4(inputPixel.x, iqPixel.yz, inputPixel.w);
    outputTexture.write(outPixel, gid);
}
