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
 constant uint &frameNum [[buffer(0)]],
 constant half &headSwitchingSpeed [[buffer(1)]],
// constant half &tScaleFactor [[buffer(2)]],
// constant half &headSwitchingPoint [[buffer(3)]],
// constant half &phaseNoise [[buffer(4)]],
// constant half &headSwitchingPhase [[buffer(5)]],
// constant uint &yOffset [[buffer(6)]],
 uint2 gid [[thread_position_in_grid]]
) {
    half4 pink = half4(1.0h);
    half4 black = half4(-1.0h, 0.0h, 0.0h, 1.0h);
    
    half phaseNoise = 1.0h / 500.0h / 262.5h;
    half headSwitchingPoint = 1.0h - (4.5h + 0.01h) / 262.5h;
    half headSwitchingPhase = (1.0h - 0.01h) / 262.5h;
    uint yOffset = 0u;
    half tScaleFactor = 262.5h;
    
    
    
    half4 rand = random.read(uint2(0u, 0u));
//    // randA between 0 and 1
    half randA = rand.x;
    uint width = input.get_width();
    uint height = input.get_height();
    
    float noise = 0.0f;
    
    if (phaseNoise != 0.0h) {
        noise = mix(-0.9999f, 0.9999f, float(randA)) * phaseNoise;
    }
    
    if (noise == 0.0f) {
        output.write(black, gid);
        return;
    }
    
    uint tWidth = width + (width / 10);
    
    float t = float(tWidth) * float(tScaleFactor);
    float animationProgress = float(frameNum) * float(headSwitchingSpeed) / 1000.0f;

    uint p = uint(fract(headSwitchingPoint + animationProgress + noise) * t);
    uint y = (2u * (p / uint(tWidth))) + yOffset;
    
    if (y >= height) {
        output.write(input.read(gid), gid);
        return;
    }
    uint flippedY = input.get_height() - 1u - gid.y;
    
    // gid.y is greater than y
    if (flippedY < y) {
        output.write(input.read(gid), gid);
        return;
    }
    
    uint newP = uint(fract(headSwitchingPhase + noise) * t);
    
//    uint x = (gid.y - y == 0) ?  p % uint(tWidth) : 0u;
//    if (gid.x < xStartingPoint) {
//        output.write(input.read(gid), gid);
//        return;
//    }

    // Computing x
    uint x = newP % tWidth;
    // Computing ishif -- what do we use this for? -- only the initial value of shif
    uint iShift = x >= (tWidth / 2) ?  x - tWidth : x;
    if (flippedY < y) {
        output.write(input.read(gid), gid);
        return;
    }
    
    // shift *= 7/16???
    float scalingFactor = 7.0f/16.0f;
    float floatShift = float(iShift) * pow(scalingFactor, float(flippedY - y));
    uint shift = uint(floatShift);
    uint x2 = (gid.x + tWidth + shift) % tWidth;
    if (x2 > width) {
        output.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
        return;
    }
    output.write(input.read(uint2(x2, gid.y)), gid);
}


