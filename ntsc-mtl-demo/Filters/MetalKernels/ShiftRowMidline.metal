//
//  ShiftRowMidline.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

#include <metal_stdlib>
using namespace metal;

kernel void shiftRowMidline
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 yiqa = inputTexture.read(gid);
    outputTexture.write(yiqa, gid);
}

