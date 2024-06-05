//
//  IIRMultiply.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirMultiply(texture2d<float, access::read_write> textureToFill [[texture(0)]], texture2d<float, access::read> initialConditionTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]) {
    float4 currentState = textureToFill.read(gid);
    float4 initialCondition = initialConditionTexture.read(gid);
    float4 product = currentState * initialCondition;
    product.w = 1.0;
    textureToFill.write(product, gid);
}
