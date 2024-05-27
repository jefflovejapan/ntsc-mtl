//
//  ChromaIntoLuma.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

constant float4 I_MULT = float4(1.0, 0.0, -1.0, 0.0);
constant float4 Q_MULT = float4(0.0, 1.0, 0.0, -1.0);

typedef enum PhaseShift: uint32_t {
    Degrees0 = 0,
    Degrees90 = 1,
    Degrees180 = 2,
    Degrees270 = 3
} PhaseShift;

/*
y_lines
    .zip(i_lines.zip(q_lines))
    .enumerate()
    .for_each(|(index, (y, (i, q)))| {
        let xi = chroma_phase_shift(phase_shift, phase_offset, info.frame_num, index * 2);

        chroma_into_luma_line(y, i, q, xi);
    });
 
 OK, we're zipping the lines together and computing xi for each tuple.
 
 The docs read that the code below calculates "the chroma subcarrier phase for a given row/field"
 
 fn chroma_phase_shift(
     scanline_phase_shift: PhaseShift,
     offset: i32,
     frame_num: usize,
     line_num: usize,
 ) -> usize {
     (match scanline_phase_shift {
         PhaseShift::Degrees90 | PhaseShift::Degrees270 => {
             (frame_num as i32 + offset + ((line_num as i32) >> 1)) & 3
         }
         PhaseShift::Degrees180 => (((frame_num + line_num) & 2) as i32 + offset) & 3,
         PhaseShift::Degrees0 => 0,
     } & 3) as usize
 }

 */

/*
fn chroma_into_luma_line(y: &mut [f32], i: &mut [f32], q: &mut [f32], xi: usize) {
    y.iter_mut()
        .zip(i.iter_mut().zip(q))
        .enumerate()
        .for_each(|(index, (y, (i, q)))| {
            let phase = (index + (xi & 3)) & 3;
            *y += *i * I_MULT[phase] + *q * Q_MULT[phase];
            // *i = 0.0;
            // *q = 0.0;
        });
}
 */

static uint32_t ChromaPhaseShift(PhaseShift phaseShift, int phaseShiftOffset, uint frameNum, int2 coord) {
    switch (phaseShift) {
        case Degrees90:
        case Degrees270:
            return (int(frameNum) + phaseShiftOffset + (coord.y >> 1)) & 3;
            
        case Degrees180:
            return (((int(frameNum) + coord.y) & 2) + phaseShiftOffset) & 3;
            
        case Degrees0:
            return 0;
    }
}

static float4 ProcessPhase(coreimage::sample_t sample, uint32_t chromaPhaseShift, int2 coord) {
    int phase = (coord.y + (chromaPhaseShift & 3)) &3;
    float newY = sample.r + (sample.g * I_MULT[phase]) + sample.b * Q_MULT[phase];
    return float4(newY, sample.g, sample.b, sample.a);
}

extern "C" float4 ChromaIntoLuma(coreimage::sample_t sample, uint32_t frameNum, PhaseShift phaseShift, int phaseShiftOffset, coreimage::destination dest) {
    int2 intCoord = int2(dest.coord());
    uint32_t chromaPhaseShift = ChromaPhaseShift(phaseShift, phaseShiftOffset, frameNum, intCoord);
    
    return ProcessPhase(sample, chromaPhaseShift, intCoord);
}


