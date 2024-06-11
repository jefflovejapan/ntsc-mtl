//
//  GeometricDistribution.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-09.
//

#include <metal_stdlib>
using namespace metal;

kernel void geometricDistribution
(
 texture2d<half, access::read> uniformRandomTexture,
 texture2d<half, access::write> outputTexture,
 constant half &probability,
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 u = uniformRandomTexture.read(gid);
    half4 result = ceil(log(half4(1.0) - u) / log(half4(1.0) - half4(probability)));
    outputTexture.write(half4(result.xyz, 1.0), gid);
}
