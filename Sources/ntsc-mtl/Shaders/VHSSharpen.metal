//
//  VHSSharpen.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void vhsSharpen
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> lowpassed [[texture(1)]],
 texture2d<half, access::write> output [[texture(2)]],
 constant half &sharpening [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inPx = input.read(gid);
    half4 lowPx = lowpassed.read(gid);
    half4 final = inPx + (inPx - lowPx) * sharpening * 2.0;
    final.w = 1.0;
    output.write(final, gid);
}
