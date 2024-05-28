//
//  ComposeLuma.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 ComposeLuma(coreimage::sample_t sample1, coreimage::sample_t sample2) {
    return float4(sample1.x, sample2.yzw);
}
