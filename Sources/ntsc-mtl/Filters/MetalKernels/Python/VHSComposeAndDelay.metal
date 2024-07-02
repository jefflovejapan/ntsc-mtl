//
//  VHSComposeAndDelay.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void vhsComposeAndDelay
(
 texture2d<half, access::read> luma [[texture(0)]],
 texture2d<half, access::read> chroma [[texture(1)]],
 texture2d<half, access::write> output [[texture(2)]],
 constant uint &chromaDelay [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 lumaPx = luma.read(gid).x;
    half4 chromaPx = chroma.read(uint2(gid.x + chromaDelay, gid.y));
    half4 outPx = half4(lumaPx.x, chromaPx.yz, lumaPx.w);
    output.write(outPx, gid);
}


