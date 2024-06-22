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
 texture2d<half, access::write> in [[texture(0)]],
 texture2d<half, access::write> prev [[texture(1)]],
 texture2d<half, access::write> out [[texture(2)]],
 constant half &alpha [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    
}
