//
//  IIRMultiply.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirMultiply
(
 texture2d<half, access::read_write> textureToFill [[texture(0)]], 
 texture2d<half, access::read> initialConditionTexture [[texture(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 currentState = textureToFill.read(gid);
    half4 initialCondition = initialConditionTexture.read(gid);
    half4 product = currentState * initialCondition;
    product.w = 1.0;
    textureToFill.write(product, gid);
}
