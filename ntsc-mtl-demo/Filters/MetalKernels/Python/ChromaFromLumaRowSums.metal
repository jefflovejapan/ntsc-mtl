//
//  ChromaFromLumaRowSums.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

kernel void chromaFromLumaRowSums
(
 texture2d<half, access::read> input [[texture(0)]],
 texture1d<half, access::write> output [[texture(1)]],
uint gid [[thread_position_in_grid]]) {
    // gid represents the row index
    uint row = gid;
    half rowValue = 0.0;

    // Sum up values of the row as an example
    for (uint x = 0; x < input.get_width(); ++x) {
        rowValue += input.read(uint2(x, row)).x;
    }
    
    // Write the computed value to the 1D texture
    output.write(rowValue, row);
}
