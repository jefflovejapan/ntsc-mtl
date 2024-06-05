//
//  IIRFilterSample.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirFilterSample
(
 texture2d<float, access::read> inputTexture [[texture(0)]],
 texture2d<float, access::read> zTex0 [[texture(1)]],
 texture2d<float, access::read_write> filteredSampleTexture [[texture(2)]],
 constant float &num0 [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    float4 result = zTex0.read(gid) + (num0 * inputTexture.read(gid));
    result.w = 1.0;
    filteredSampleTexture.write(result, gid);
}
