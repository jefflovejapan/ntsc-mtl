//
//  ChromaIntoLuma.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
#include "ChromaAndLumaOffsets.metal"
using namespace metal;

kernel void chromaIntoLuma(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant ChromaPhaseShift &phaseShift [[buffer(0)]],
    constant int &phaseShiftOffset [[buffer(1)]],
    constant half &subcarrierAmplitude [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int idx = phaseShiftIndex(gid.y, phaseShift, phaseShiftOffset);
    half iFactor = UMult[idx];
    half qFactor = VMult[idx];
    half4 inPx = input.read(gid);
    
    half inI = inPx.y;
    half chroma = (inI * subcarrierAmplitude * iFactor);
    half inQ = inPx.z;
    chroma += (inQ * subcarrierAmplitude * qFactor);
    inPx.x += (chroma / subcarrierAmplitude);
    output.write(inPx, gid);
}

