//
//  Snow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

constant half PI_16 = half(3.140625);

half sampleGeometric
(
 half u,    // uniform random variable
 half p     // line snow intensity
 ) {
    return log(u) / log(p);
}

kernel void snow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant float &intensity [[buffer(0)]],
 constant float &anisotropy [[buffer(1)]],
 constant half &bandwidthScale [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 inputPixel = inputTexture.read(gid);
    half4 randomPixel = randomTexture.read(gid);    // uniform random values
    // half thing = smoothstep(half(0.0), half(intensity) * (half(1.0) - half(anisotropy)), randomPixel.x);
    // half smoothedSnow = mix(half(intensity), half(1.0), (half(1.0) - half(anisotropy))) * thing;
//    half i = 1.0h - half(intensity);
//    half a = 1.0h - half(anisotropy);
//    half bottom = max(half(0.0), i - a);
//    half snow = smoothstep(bottom, i, randomPixel.x);
//  half snow = step(half(intensity), randomPixel.x) * 0.125h;
    half p = half(intensity);
    half s = half(anisotropy);
    half bottom = (1.0h - p) - (.5h * (1.0h - s));
    half top = (1.0h - p) + (.5h * (1.0h - s));
    half snow = clamp(smoothstep(bottom, top, randomPixel.x), 0.0h, 1.0h) * 0.125h;
    
    
    
    half4 outPx = inputPixel;
    outPx.x += snow;
    outputTexture.write(outPx, gid);
    
//    half smoothedSnow = half(0.0);
//    if (anisotropy == half(0.0)) {
//        smoothedSnow = intensity;
//    } else {
//        smoothedSnow = half(1.0); // (with probability 1.0 - intensity)
//    }
//    half smoothedSnow = smoothstep(half(anisotropy), half(1.0), randomPixel.x) * half(0.125);
//    half4 outPx = inputPixel;
//    outPx.x += half(smoothedSnow);
//    outputTexture.write(outPx, gid);
//    return;
}
    
////    half snowIntensity = snowIntensityTexture.read(gid).x;
//    
//    // Already used x to calculate snow intensity
//    half transientLenRnd = randomPixel.y;   // i    0.5
//    half transientFreqRnd = randomPixel.z;  // q    0.5
//    half finalTermRnd = randomPixel.w;      // alpha    0.5
//    
//    float transientLen = mix(8.0, 64.0, float(transientLenRnd)) * float(bandwidthScale);    // 30
//    float transientFreq = mix(transientLen * 3.0, transientLen * 5.0, float(transientFreqRnd)); // 120
//    
//    float x = float(gid.x);
//    // 3.14 * 0 *...) --> cos(0) is 1 (I think)
//    /*
//     row[i] += ((x * PI) / transient_freq).cos()
//     domain is -1 to 1
//     */
//    // cosTerm is 1 for x == 0
//    float cosTerm = cos((M_PI_F * x) / transientFreq);
//    /*
//     * (1.0 - x / transient_len).powi(2)
//     * transient_rng.gen_range(-1.0..2.0);
//     */
//    // transientLenTerm = 1 for x == 0
//    float transientLenTerm = pow(float(1.0) - (x / transientLen), float(2.0));
//    
//    // final term can either be -1, 0, 1, or 2
//    // so product can either be -1, 0, 1, or 2
//    float finalTerm = mix(-1.0, 2.0, float(finalTermRnd));
//    
//    /*
//     row[i] += ((x * PI) / transient_freq).cos()
//         * (1.0 - x / transient_len).powi(2)
//         * transient_rng.gen_range(-1.0..2.0);
//     
//     cosTerm * transientLenTerm * finalTerm
//     */
//    half mod = half(cosTerm * transientLenTerm * finalTerm);
//    if (mod < 0.0) {
//        outputTexture.write(half4(half(0.2), half(0.2), half(0.2), 1.0), gid);
//        return;
//    }
//    half4 modPixel = inputPixel;
//    modPixel.x += mod;
//    outputTexture.write(modPixel, gid);
//}
