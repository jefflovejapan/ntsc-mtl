//
//  File.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-07-29.
//

#include <metal_stdlib>
using namespace metal;

kernel void myThing
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    outputTexture.write(inputTexture.read(gid), gid);
}
