//
//  ChromaIntoLumaTextureFilter.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

constant half4 I_MULT = half4(1.0, 0.0, -1.0, 0.0);
constant half4 Q_MULT = half4(0.0, 1.0, 0.0, -1.0);

typedef enum PhaseShift: uint32_t {
    Degrees0 = 0,
    Degrees90 = 1,
    Degrees180 = 2,
    Degrees270 = 3
} PhaseShift;

static uint32_t ChromaPhaseShift(PhaseShift phaseShift, int phaseShiftOffset, uint32_t timestamp, int2 coord) {
    switch (phaseShift) {
        case Degrees90:
        case Degrees270:
            return (int(timestamp) + phaseShiftOffset + (coord.y >> 1)) & 3;
            
        case Degrees180:
            return (((int(timestamp) + coord.y) & 2) + phaseShiftOffset) & 3;
            
        case Degrees0:
            return 0;
    }
}

static half4 ProcessPhase(half4 yiqSample, uint32_t chromaPhaseShift, uint2 coord) {
    int phase = (coord.y + (chromaPhaseShift & 3)) &3;
    float newY = yiqSample.x + (yiqSample.y * I_MULT[phase]) + yiqSample.z * Q_MULT[phase];
    return half4(newY, yiqSample.y, yiqSample.z, yiqSample.w);
}

kernel void chromaIntoLuma
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::write> outputTexture [[texture(1)]],
 constant uint32_t &timestamp [[buffer(0)]],
 constant PhaseShift &phaseShift [[buffer(1)]],
 constant int &phaseShiftOffset [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 yiqSample = inputTexture.read(gid);
    int2 intCoord = int2(gid);
    uint32_t chromaPhaseShift = ChromaPhaseShift(phaseShift, phaseShiftOffset, timestamp, intCoord * 2);
    half4 yiqResult = ProcessPhase(yiqSample, chromaPhaseShift, gid);
    half3 yiq = yiqResult.xyz;
    yiq = clampYIQ(yiq);
    half4 yiqa = half4(yiq, 1.0);
    outputTexture.write(yiqa, gid);
}
