//
//  CompositePreemphasis.metal
//  
//
//  Created by Jeffrey Blagdon on 2024-07-02.
//

#include <metal_stdlib>
using namespace metal;

kernel void compositePreemphasis
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> highpassed [[texture(1)]],
 texture2d<half, access::write> output [[texture(2)]],
 constant half &preemphasis [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inPx = input.read(gid);
    half highY = highpassed.read(gid).x;
    inPx.x += (highY * preemphasis);
    output.write(inPx, gid);
}

