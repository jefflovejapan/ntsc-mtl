//
//  ComposeAndDelay.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

#include <metal_stdlib>
using namespace metal;

kernel void composeAndDelay
(
 texture2d<half, access::read> y [[texture(0)]],
 texture2d<half, access::read> i [[texture(1)]],
 texture2d<half, access::read> q [[texture(2)]],
 texture2d<half, access::write> out [[texture(3)]],
 constant uint &iDelay [[buffer(0)]],
 constant uint &qDelay [[buffer(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    uint2 iCoord = uint2(gid.x - iDelay, gid.y);
    half4 iPx = i.read(iCoord);
    uint2 qCoord = uint2(gid.x - qDelay, gid.y);
    half4 qPx = q.read(qCoord);
    half4 yPx = y.read(gid);
    out.write(half4(yPx.x, iPx.y, qPx.z, yPx.w), gid);
}
