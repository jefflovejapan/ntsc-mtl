//
//  ChromaFromLumaAccumulator.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void chromaFromLumaAccumulator
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::write> output [[texture(1)]],
 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x != 0) {
        return;
    }
    half rowValue = 0.0h;
    half4 inPx = input.read(gid);
    uint row = gid.y;
    uint width = input.get_width();

    // Sum up values of the row as an example
    for (uint x = 0; x < input.get_width(); ++x) {
        half y2 = (x + 2 < width) ? input.read(uint2(x + 2, row)).x : half(0.0);
        half yd4 = (x >= 2) ? input.read(uint2(x - 2, row)).x : half(0.0);
        rowValue += (y2 - yd4);
    }
    inPx.x = rowValue * 0.25h;
    output.write(inPx, gid);
}
