//
//  HeadSwitching.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-25.
//

#include <metal_stdlib>
using namespace metal;

kernel void headSwitching
(
 texture2d<half, access::read> input [[texture(0)]],
 texture2d<half, access::read> random [[texture(1)]],
 texture2d<half, access::write> output [[texture(2)]],
 constant half &phaseNoise [[buffer(0)]],
 constant half &headSwitchingPoint [[buffer(1)]],
 constant half &tScaleFactor [[buffer(2)]],
 constant half &headSwitchingPhase [[buffer(3)]],
 constant half &headSwitchingSpeed [[buffer(4)]],
 constant uint &yOffset [[buffer(5)]],
 uint2 gid [[thread_position_in_grid]]
) {
    half4 noisePx = random.read(uint2(0, gid.y));
    half noiseA = noisePx.x;
    
    uint width = input.get_width();
    
    float noise = 0.0f;
    
    if (phaseNoise != 0.0h) {
        int x = mix(1, 2000000000, noiseA);
        noise = (float(x) / 1000000000.0f - 1.0f) * float(phaseNoise);
    }
    uint tWidth = width + (width / 10);
    float t = float(tWidth) * float(tScaleFactor);
    int p = int(fract(headSwitchingPoint + noise) * t);
    float startingPoint = headSwitchingPoint + (headSwitchingSpeed / 1000.0f);
    uint y = uint(uint(p) / (2u * uint(tWidth)));
    y -= yOffset;
    
    if (gid.y > y) {
        output.write(input.read(gid), gid);
        return;
    }
    
    uint xStartingPoint = (gid.y - y == 0) ?  uint(p) % uint(tWidth) : 0u;
    if (gid.x < xStartingPoint) {
        output.write(input.read(gid), gid);
        return;
    }
    uint shift = uint(float(gid.y - y) * 7.0f / 16.0f);
    uint x2 = (gid.x + shift) % tWidth;
    if (x2 >= width) {
        output.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
        return;
    }
    output.write(input.read(uint2(x2, gid.y)), gid);
}


