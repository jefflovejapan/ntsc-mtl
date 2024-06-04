//
//  IIRFilterSample.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

kernel void iirFilterSample(texture2d<float, access::read_write> inputTexture [[texture(0)]], texture2d<float, access::read_write> zTex0 [[texture(1)]], texture2d<float, access::read_write> filteredSampleTexture [[texture(2)]], constant float &num0 [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    float minWidth = min(min(inputTexture.get_width(), zTex0.get_width()), filteredSampleTexture.get_width());
    float minHeight = min(min(inputTexture.get_height(), zTex0.get_height()), filteredSampleTexture.get_height());
    if (gid.x >= minWidth || gid.y >= minHeight) {
        return;
    }
    float4 result = zTex0.read(gid) + (num0 * inputTexture.read(gid));
    filteredSampleTexture.write(result, gid);
}
