//
//  YIQ.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

constant float3x3 rgbToYIQMatrix = float3x3
(
 float3(0.299, 0.5959, 0.2115),
 float3(0.587, -0.2746, -0.5227),
 float3(0.114, -0.3213, 0.3112)
 );

kernel void convertToYIQ(texture2d<float, access::read_write> texture [[texture(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    // Read the pixel at the current thread position
    float4 color = texture.read(gid);

    // Convert RGB to YIQ using the matrix
    float3 rgb = float3(color.r, color.g, color.b);
    float3 yiq = rgbToYIQMatrix * rgb;

    // Write the converted YIQ values back to the texture
    texture.write(float4(yiq, 1.0), gid);
}

