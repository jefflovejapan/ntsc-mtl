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
 uint2 gid [[thread_position_in_grid]]
) {
//    half4 rand = random.read(uint2(0, gid.y));
//    // randA between 0 and 1
//    half randA = rand.x;
    uint width = input.get_width();
//    
//    float noise = 0.0f;
//    
//    if (phaseNoise != 0.0h) {
//        noise = mix(-1.0f, 1.0f, float(randA)); // Ignoring phase noise multiplier
//    }
    
    uint tWidth = width + (width / 10);
    
//    float t = float(tWidth) * float(tScaleFactor);
    
    float animationProgress = float(frameNum) * 50.0f / 1000.0f;
    float fModdedProgress = fmod(animationProgress, 1.0f);
    half halfAnim = half(fModdedProgress);
    half4 inPx = input.read(gid);
    inPx.y = halfAnim;
    output.write(inPx, gid);
//    output.write(<#vec<half, 4> color#>, <#ushort2 coord#>)
//    if (frameNum % 20u == 0u) {
//        output.write(half4(1.0h, 1.0h, 1.0h, 1.0h), gid);
//    } else {
//        output.write(input.read(gid), gid);
//    }
//    uint moddedY = uint(fmod(animationProgress * float(input.get_height()), float(input.get_height())));
//    if (gid.y < moddedY) {
//        output.write(half4(1.0h, 1.0h, 1.0h, 1.0h), gid);
//    } else {
//        output.write(input.read(gid), gid);
//    }
//    uint p = uint(fract(/*headSwitchingPoint + */animationProgress /*+ noise*/) * t);
//    
//    uint y = p / (2u * uint(tWidth));
//    y -= yOffset;
//    
//    // gid.y is greater than y
//    if (gid.y > y) {
//        output.write(input.read(gid), gid);
//        return;
//    }
//    
//    uint xStartingPoint = (gid.y - y == 0) ?  uint(p) % uint(tWidth) : 0u;
//    if (gid.x < xStartingPoint) {
//        output.write(input.read(gid), gid);
//        return;
//    }
//
//    // gid.y is less than y
//    uint shift = uint(float(y - gid.y) * 7.0f / 16.0f);
//    uint x2 = (gid.x + shift) % tWidth;
//    if (x2 > width) {
//        output.write(half4(0.0h, 0.0h, 0.0h, 1.0h), gid);
//        return;
//    }
//    output.write(input.read(uint2(x2, gid.y)), gid);
}


