//
//  Paint.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

#include <metal_stdlib>
using namespace metal;

kernel void paint
(
 texture2d<half, access::write> texture [[texture(0)]],
 constant half4 &color [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
//    half minWidth = min(textureToFill.get_width(), sideEffectedTexture.get_width());
//    half minHeight = min(textureToFill.get_height(), sideEffectedTexture.get_height());
//    if (gid.x >= minWidth || gid.y >= minHeight) {
//        return;
//    }
    texture.write(color, gid);
}
