//
//  IIRInitialCondition.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirInitialCondition
(
 texture2d<half, access::read_write> textureToFill [[texture(0)]],
 texture2d<half, access::read_write> sideEffectedTexture [[texture(1)]], 
 constant half &aSum [[buffer(0)]],
 constant half &cSum [[buffer(1)]], 
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 initialCondition = textureToFill.read(gid);
    half4 sideEffected = sideEffectedTexture.read(gid);
    half4 output = ((aSum * sideEffected) - cSum) * initialCondition;
    output.w = 1.0;
    textureToFill.write(output, gid);
}
