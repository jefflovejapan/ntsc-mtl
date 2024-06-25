//
//  HeadSwitching.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-25.
//

#include <metal_stdlib>
using namespace metal;

kernel void headSwitching(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    
}


