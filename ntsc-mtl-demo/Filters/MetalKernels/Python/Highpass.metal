//
//  Highpass.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void highpass
(
 texture2d<half, access::read> in [[texture(0)]],
 texture2d<half, access::read> lowpassed [[texture(1)]],
 texture2d<half, access::write> out [[texture(2)]],
 constant half &alpha [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inPx = in.read(gid);
    half4 lowPx = lowpassed.read(gid);
    
    half4 outPx = inPx - lowPx;
    outPx.w = 1.0;
    out.write(outPx, gid);
}

