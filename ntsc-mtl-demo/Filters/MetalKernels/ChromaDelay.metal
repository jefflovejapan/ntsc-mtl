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
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &horizShift [[buffer(0)]],
 constant int &vertShift [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inputPixel = inputTexture.read(gid);
    int vertShiftedY = int(gid.y);
    vertShiftedY += vertShift;
    vertShiftedY = clamp(vertShiftedY, 0, int(inputTexture.get_height()));
    uint2 vertShiftedPos = uint2(gid.x, vertShiftedY);
    half4 vertShiftedPixel = inputTexture.read(vertShiftedPos);
    half4 combinedPixel = half4(inputPixel.x, vertShiftedPixel.yz, inputPixel.w);
    outputTexture.write(combinedPixel, gid);
}
