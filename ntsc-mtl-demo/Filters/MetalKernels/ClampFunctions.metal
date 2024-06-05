//
//  ClampYIQ.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include <metal_stdlib>
using namespace metal;

inline half3 clampYIQ(half3 yiq) {
    yiq.x = clamp(yiq.x, half(-1.0), half(1.0));
    yiq.y = clamp(yiq.y, half(-0.5957), half(0.5957));
    yiq.z = clamp(yiq.z, half(-0.5226), half(0.5226));
    return yiq;
}
