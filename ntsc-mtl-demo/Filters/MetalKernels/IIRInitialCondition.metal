//
//  IIRInitialCondition.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirInitialCondition(texture2d<float, access::read_write> textureToFill [[texture(0)]], texture2d<float, access::read_write> sideEffectedTexture [[texture(1)]], constant float &aSum [[buffer(0)]], constant float &cSum [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
    float minWidth = min(textureToFill.get_width(), sideEffectedTexture.get_width());
    float minHeight = min(textureToFill.get_height(), sideEffectedTexture.get_height());
    if (gid.x >= minWidth || gid.y >= minHeight) {
        return;
    }
    float4 initialCondition = textureToFill.read(gid);
    float4 sideEffected = sideEffectedTexture.read(gid);
    float4 output = ((aSum * sideEffected) - cSum) * initialCondition;
    textureToFill.write(output, gid);
}
