//
//  VHSSumAndScale.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void vhsSumAndScale
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> pre [[texture(1)]],
 texture2d<half, access::read> triple [[texture(2)]],
 texture2d<half, access::write> out [[texture(3)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half preY = pre.read(gid).x;
    half tripleY = triple.read(gid).x;
    half summedY = tripleY + (preY * 1.6);
    half4 outPx = input.read(gid);
    outPx.x = summedY;
    out.write(outPx, gid);
}

