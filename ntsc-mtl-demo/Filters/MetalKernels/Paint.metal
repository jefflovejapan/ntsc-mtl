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
    texture.write(color, gid);
}
