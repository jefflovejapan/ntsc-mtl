//
//  ChromaFromLuma.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include "ChromaAndLumaOffsets.metal"
#include <metal_stdlib>
using namespace metal;

kernel void chromaFromLuma
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::write> output [[texture(1)]],
 constant ChromaPhaseShift &phaseShift [[buffer(0)]],
 constant int &phaseShiftOffset [[buffer(1)]],
 constant half &subcarrierAmplitude [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inPx = input.read(gid);
    half acc4 = inPx.x;
    half y2 = (gid.x + 2 < input.get_width()) ? input.read(uint2(gid.x + 2, gid.y)).x : 0.0h;
    half chroma = y2 - acc4;
    uint xi = phaseShiftIndex(gid.y, phaseShift, phaseShiftOffset);
    uint x = 4 - xi & 3;
    uint index = gid.x - x;
    if (index % 4 == 2 || index % 4 == 3) {
        chroma = -chroma;
    }
    
    inPx.y = (inPx.y - chroma) * 0.5h;
    inPx.z = (inPx.z - chroma) * 0.5h;
    output.write(inPx, gid);
}
