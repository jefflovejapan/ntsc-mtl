//
//  ChromaAndLumaOffsets.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

#include <metal_stdlib>
using namespace metal;

constant half4 UMult = half4(1.0h, 0.0h, -1.0h, 0.0h);
constant half4 VMult = half4(0.0h, 1.0h, 0.0h, -1.0h);

enum ChromaPhaseShift {
    ChromaPhaseShift0  = 0,
    ChromaPhaseShift90 = 1,
    ChromaPhaseShift180 = 2,
    ChromaPhaseShift270 = 3
};

inline int phaseShiftIndex(uint y, ChromaPhaseShift phaseShift, int phaseShiftOffset) {
    int fieldNo = y % 2;
    switch (phaseShift) {
        case ChromaPhaseShift0:
            return (fieldNo + phaseShiftOffset + (y >> 1)) & 3;
        case ChromaPhaseShift90:
            return (fieldNo + phaseShiftOffset + (y >> 1)) & 3;
        case ChromaPhaseShift180:
            return ((((fieldNo + y) & 2) + phaseShiftOffset) & 3);
        case ChromaPhaseShift270:
            return ((fieldNo + phaseShiftOffset) & 3);
        default:
            return 0;
    }
}
