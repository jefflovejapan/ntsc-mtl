//
//  ChromaPhaseNoise.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

#include <metal_stdlib>
using namespace metal;

constant half PI_16 = half(3.140625);

kernel void chromaPhaseNoise
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &intensity [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inputPixel = inputTexture.read(gid);
    half rand = randomTexture.read(gid).x;
    half y = inputPixel.x;
    half i = inputPixel.y;
    half q = inputPixel.z;
    half a = inputPixel.w;
    half phaseShift = (rand - half(0.5)) * 4.0 * intensity * PI_16;
    half sinAngle = sin(phaseShift);
    half cosAngle = cos(phaseShift);
    half rotatedI = (i * cosAngle) - (q * sinAngle);
    half rotatedQ = (i * sinAngle) + (q * cosAngle);
    half4 final = half4(y, rotatedI, rotatedQ, a);
    outputTexture.write(final, gid);
}
