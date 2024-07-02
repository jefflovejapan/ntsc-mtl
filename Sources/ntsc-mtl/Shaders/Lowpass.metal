//
//  Lowpass.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

#include <metal_stdlib>
using namespace metal;

kernel void lowpass
(
 texture2d<half, access::read> in [[texture(0)]],
 texture2d<half, access::read> prev [[texture(1)]],
 texture2d<half, access::write> out [[texture(2)]],
 constant half &alpha [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 samplePx = in.read(gid);
    half4 stage1 = samplePx * alpha;
    half4 prevPx = prev.read(gid);
    half4 stage2 = prevPx - (prevPx * alpha);
    half4 outPx = half4(stage1.xyz + stage2.xyz, samplePx.w);
    out.write(outPx, gid);
}
