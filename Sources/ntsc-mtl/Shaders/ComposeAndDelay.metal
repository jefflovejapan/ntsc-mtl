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
    // Read y texture pixel
    half4 yPx = y.read(gid);

    // Calculate coordinates for i and q textures
    uint2 iCoord = gid + uint2(iDelay, 0);
    uint2 qCoord = gid + uint2(qDelay, 0);

    // Ensure coordinates are within bounds
    iCoord.x = min(iCoord.x, i.get_width() - 1);
    qCoord.x = min(qCoord.x, q.get_width() - 1);

    // Read i and q texture pixels
    half4 iPx = i.read(iCoord);
    half4 qPx = q.read(qCoord);

    // Write the composed pixel to the output texture
    out.write(half4(yPx.x, iPx.y, qPx.z, yPx.w), gid);
}
