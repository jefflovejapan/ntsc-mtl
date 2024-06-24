//
//  LumaIntoChroma.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
#include "ChromaAndLumaOffsets.metal"
using namespace metal;

kernel void lumaIntoChroma
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::write> output [[texture(1)]],
 constant ChromaPhaseShift &phaseShift [[buffer(0)]],
 constant int &phaseShiftOffset [[buffer(1)]],
 constant half &subcarrierAmplitude [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    
}

