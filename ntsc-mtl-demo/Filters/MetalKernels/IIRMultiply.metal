//
//  IIRMultiply.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

kernel void iirMultiply
(
 texture2d<half, access::read> z0Texture [[texture(0)]],
 texture2d<half, access::read> initialConditionTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(textureToFill.get_width(), initialConditionTexture.get_width());
//    half minHeight = min(textureToFill.get_height(), initialConditionTexture.get_height());
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    half4 currentState = z0Texture.read(gid);
    half4 initialCondition = initialConditionTexture.read(gid);
    half4 product = currentState * initialCondition;
    half3 productYIQ = product.xyz;
    productYIQ = clampYIQ(productYIQ);
    half4 yiqa = half4(productYIQ, 1.0);
    outputTexture.write(yiqa, gid);
}
